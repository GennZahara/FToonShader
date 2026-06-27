#ifndef FEEL_HAIR_FRAGMENT_INCLUDED
#define FEEL_HAIR_FRAGMENT_INCLUDED

//  Feel_HairFragment.hlsl — Feel_Hair.shader 전용 Fragment
//  CBUFFER(UnityPerMaterial) + 텍스처 선언.
//
//  렌더링 파이프라인 (NPR Two-Tone):
//    Albedo × BaseColor
//      → CelShading (Ramp 또는 Smoothstep) → shadowFactor
//        → shadowColor = albedo × shadowTintMul  (씬 앰비언트와 무관한 고정 색상)
//          litColor    = albedo × lightColor
//          finalColor  = lerp(shadowColor, litColor, shadowFactor)
//            → SSS (역광 반투과, Additive)
//              → RimLight (Fresnel 실루엣, Additive)
//                → KajiyaKay Primary + Secondary (_UseHairHighlight uniform 분기)
//
//  모든 기능 토글은 _UseX uniform float 분기 (런타임 변경, shader_feature 미사용 → 변종 컴파일 없음).
//  _UseHairHighlight ON → 두 개의 하이라이트 밴드 (Primary + Secondary), OFF → 하이라이트 없음.
// ============================================================================

#include "Feel_Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Feel_Functions.hlsl"

// ── 텍스처 ────────────────────────────────────────────────────────────────────
// 텍스쳐와 라이트맵 선언
TEXTURE2D(_MainTex);     SAMPLER(sampler_MainTex);
TEXTURE2D(_RampTexture); SAMPLER(sampler_RampTexture);
TEXTURE2D(_LightMap);    SAMPLER(sampler_LightMap);
TEXTURE2D(_MatCapTex);   SAMPLER(sampler_MatCapTex);


// ── CBUFFER — Feel_Hair.shader 전용 ──────────────────────────────────────────
CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _RampTexture_ST;
    float4 _LightMap_ST;
    float4 _BaseColor;

    // Alpha Cutout
    float  _Cutoff;

    // Cel Shading
    float  _CelSteps;
    float  _ShadowThreshold;
    float  _ShadowSmoothness;

    // Shadow Tint (1st Shadow)
    float4 _ShadowTint;
    float  _ShadowStrength;

    // Shadow Tint (2nd Shadow)
    float4 _ShadowTint2;
    float  _ShadowStrength2;
    float  _Shadow2Threshold;
    float  _Shadow2Smoothness;

    // Stylized SSS
    float4 _SSSColor;
    float  _SSSScale;
    float  _SSSDistortion;
    float  _GradientRange;
    float  _GradientStrength;

    // Rim Light
    float4 _RimColor;
    float  _RimPower;
    float  _RimIntensity;

    // Rim Shade
    float4 _RimShadeColor;
    float  _RimShadePower;
    float  _RimShadeThreshold;
    float  _RimShadeSmoothness;
    float  _RimShadeIntensity;

    // Kajiya-Kay Primary Highlight
    float4 _HairSpecColor1;
    float  _HairShift1;
    float  _HairExp1;
    float  _HairInt1;

    // Kajiya-Kay Secondary Highlight
    float4 _HairSpecColor2;
    float  _HairShift2;
    float  _HairExp2;
    float  _HairInt2;

    // MatCap
    float4 _MatCapColor;
    float  _MatCapIntensity;

    // Kajiya-Kay Toon Step
    float  _HairToonThreshold;
    float  _HairToonSmoothness;

    // Outline (Outline Pass에서도 CBUFFER 일관성 유지)
    float4 _OutlineColor;
    float  _OutlineWidth;

    // Toggle floats — SRP Batcher 규칙
    float  _UseRampTex;
    float  _UseFloor;
    float  _UseShadow1st;
    float  _UseShadow2nd;
    float  _UseHairHighlight;
    float  _UseSSS;
    float  _UseRimLight;
    float  _UseRimShade;
    float  _UseMatCap;
    float  _UseLightMap;
    float  _UseVirtualStrand;
    float  _UseBitangent;
    float  _UseKayToon;
    float  _UseAlphaClip;

    // Stencil (SRP Batcher 규정 — render state 참조용)
    float  _StencilRef;
    float  _StencilReadMask;
    float  _StencilWriteMask;
    float  _StencilComp;
    float  _StencilPass;
    float  _StencilFail;
    float  _StencilZFail;

    // Debug Output (0=Off, 1=ShadowFactor, 2=Normal, 3=SDF)
    float  _DebugMode;

CBUFFER_END


// ── Fragment ──────────────────────────────────────────────────────────────────

float4 FeelHairFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // ── 벡터 계산 ────────────────────────────────────────────────────────────
    float3 N = normalize(input.normalWS);
    float3 V = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));

    // ── Kajiya-Kay 탄젠트 방향 결정 ──────────────────────────────────────────
    //  우선순위: Virtual Strand > Bitangent > Tangent (기본)
    // (uniform float 분기 — 런타임 토글 시 변종 컴파일 없음)
    float3 T;
    if (_UseVirtualStrand > 0.5)
    {
        // Virtual Strand: 월드 업(모발 기준 방향)을 Gram-Schmidt로 표면 위에 투영.
        // UV 품질에 무관하게 일관된 모발 방향을 보장.
        // 정수리처럼 법선이 월드 업과 거의 평행할 때 → T_gs ≈ 0 → 월드 포워드로 폴백.
        float3 vsUp  = float3(0.0, 1.0, 0.0);
        float3 T_gs  = vsUp - N * dot(N, vsUp);

        float3 vsFwd = float3(0.0, 0.0, 1.0);
        float3 T_fwd = vsFwd - N * dot(N, vsFwd);

        T = normalize(lerp(T_fwd, T_gs, saturate(dot(T_gs, T_gs) * 1000.0)));
    }
    else if (_UseBitangent > 0.5)
    {
        // UV V방향 (헤어 카드 표준 UV: U=폭, V=모발 길이)
        T = normalize(input.bitangentWS);
    }
    else
    {
        // UV U방향 (기본)
        T = normalize(input.tangentWS);
    }

    // ── 메인 라이트 ───────────────────────────────────────────────────────────
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light  mainLight   = GetMainLight(shadowCoord);
    float3 L           = normalize(mainLight.direction);
    float3 H           = normalize(L + V);

    float  atten      = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    float3 lightColor = mainLight.color * atten;

    // ── Albedo ────────────────────────────────────────────────────────────────
    float2 uv     = TRANSFORM_TEX(input.uv, _MainTex);
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * _BaseColor;

    // Alpha Cutout — ShadowCaster 패스도 동일 기준으로 잘라 실루엣 일치
    FeelAlphaClip(albedo.a, _UseAlphaClip, _Cutoff);

    // ── Light Map 샘플링 ──────────────────────────────────────────────────────
    //  R: Shadow Threshold Map — 픽셀별 그림자 경계
    //  G: Specular Mask        — Kajiya-Kay 하이라이트 강도 제어
    //  B: Rim Light Mask
    // 호이스팅: lm* 값은 LightMap OFF일 때도 뒤 분기에서 참조되므로 기본값으로 선언 (Main 패턴과 동일)
    half lmShadowThreshold = 0.5;
    half lmSpecMask        = 1.0;
    half lmRimMask         = 1.0;
    if (_UseLightMap > 0.5)
    {
        float2 lightMapUV     = TRANSFORM_TEX(input.uv, _LightMap);
        float4 lightMapSample = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, lightMapUV);
        // R채널을 0.25~0.75 범위로 리매핑 — 극단값 방지
        lmShadowThreshold = (half)(lightMapSample.r * 0.5 + 0.25);
        lmSpecMask        = (half)lightMapSample.g;
        lmRimMask         = (half)lightMapSample.b;
    }

    // raw NdotL (SSS 계산용, Half-Lambert 아님)
    half rawNdotL = (half)dot(N, L);

    // ── Shadow Factor (Cel Shading) ───────────────────────────────────────────
    half shadowArea = GetShadowArea(rawNdotL, (half)atten);

    // 우선순위: LightMap > RampTex > Smoothstep (기존 #ifdef/#elif 순서 유지)
    half shadowFactor;
    if (_UseLightMap > 0.5)
    {
        shadowFactor = GetCelShadingSmooth(shadowArea, lmShadowThreshold, (half)_ShadowSmoothness);
    }
    else if (_UseRampTex > 0.5)
    {
        float2 rampUV;
        if (_UseFloor > 0.5)
            rampUV = GetRampUV_Floor(shadowArea, (half)_CelSteps);
        else
            rampUV = GetRampUV_Direct(shadowArea);
        shadowFactor = (half)SAMPLE_TEXTURE2D(_RampTexture, sampler_RampTexture, rampUV).r;
    }
    else
    {
        shadowFactor = GetCelShadingSmooth(shadowArea, (half)_ShadowThreshold, (half)_ShadowSmoothness);
    }

    // ── 2nd Shadow Factor ─────────────────────────────────────────────────────
    half shadowFactor2 = 1.0;
    if (_UseShadow2nd > 0.5)
        shadowFactor2 = GetCelShadingSmooth(shadowArea, (half)_Shadow2Threshold, (half)_Shadow2Smoothness);

    // ── NPR Two-Tone Diffuse ──────────────────────────────────────────────────
    float3 albedoRGB = (float3)albedo.rgb;

    float3 shadowMul = (_UseShadow1st > 0.5)
        ? lerp(float3(1.0, 1.0, 1.0), (float3)_ShadowTint.rgb, _ShadowStrength)
        : float3(0.6, 0.62, 0.72);

    float3 shadowColor = albedoRGB * shadowMul;
    float3 litColor    = albedoRGB * lightColor;

    // ── 합성 ─────────────────────────────────────────────────────────────────
    float3 finalColor;
    if (_UseShadow2nd > 0.5)
    {
        float3 shadow2Mul   = lerp(float3(1.0, 1.0, 1.0), (float3)_ShadowTint2.rgb, _ShadowStrength2);
        float3 shadow2Color = albedoRGB * shadow2Mul;
        float3 shadowMix    = lerp(shadow2Color, shadowColor, (float)shadowFactor2);
        finalColor          = lerp(shadowMix, litColor, (float)shadowFactor);
    }
    else
    {
        finalColor = lerp(shadowColor, litColor, (float)shadowFactor);
    }

    // ── Ambient (SH) — 환경광 채우기 (Ambient Intensity 슬라이더로 제어, 그림자도 들어올림)
    finalColor += albedoRGB * max((float3)0.0, (float3)input.vertexSH);

    // ── Stylized SSS ──────────────────────────────────────────────────────────
    if (_UseSSS > 0.5)
    {
        finalColor += (float3)GetSSS(
            (half3)N, (half3)L, (half3)V,
            (half3)_SSSColor.rgb, (half3)lightColor,
            (half)_SSSScale, (half)_SSSDistortion,
            (half)_GradientRange, (half)_GradientStrength
        );
    }

    // ── Rim Light ─────────────────────────────────────────────────────────────
    if (_UseRimLight > 0.5)
    {
        half3 rimContrib = GetRimLight(
            (half3)N, (half3)V,
            (half3)_RimColor.rgb,
            (half)_RimPower, (half)_RimIntensity
        );
        if (_UseLightMap > 0.5)
            rimContrib *= lmRimMask;
        finalColor = 1.0 - (1.0 - finalColor) * (1.0 - (float3)rimContrib);
    }

    // ── Kajiya-Kay 헤어 하이라이트 ────────────────────────────────────────────
    if (_UseHairHighlight > 0.5)
    {
        float hl1 = CalculateKajiyaKay(T, H, _HairShift1, _HairExp1);
        float hl2 = CalculateKajiyaKay(T, H, _HairShift2, _HairExp2);

        if (_UseLightMap > 0.5)
        {
            hl1 *= (float)lmSpecMask;
            hl2 *= (float)lmSpecMask;
        }

        if (_UseKayToon > 0.5)
        {
            float kayEdge0 = saturate(_HairToonThreshold - _HairToonSmoothness);
            float kayEdge1 = saturate(_HairToonThreshold + _HairToonSmoothness);
            hl1 = smoothstep(kayEdge0, kayEdge1, hl1);
            hl2 = smoothstep(kayEdge0, kayEdge1, hl2);
        }

        finalColor += hl1 * _HairInt1 * (float3)_HairSpecColor1.rgb * lightColor;
        finalColor += hl2 * _HairInt2 * (float3)_HairSpecColor2.rgb * lightColor;
    }

    // ── MatCap ────────────────────────────────────────────────────────────────
    if (_UseMatCap > 0.5)
    {
        finalColor += (float3)GetMatCap(
            TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex),
            (half3)N,
            (half3)_MatCapColor.rgb, (half)_MatCapIntensity, shadowFactor
        );
    }

    // ── Additional Lights 루프 ────────────────────────────────────────────────
    //  광원별 cel diffuse를 누적한 뒤 saturate로 합을 클램프 → 다중 포인트라이트 블로우아웃 방지.
    uint  additionalLightCount = GetAdditionalLightsCount();
    half3 addDiffuse           = 0.0h;
    for (uint i = 0u; i < additionalLightCount; i++)
    {
        Light addLight  = GetAdditionalLight(i, input.positionWS);
        half  addNdotL  = (half)dot(N, addLight.direction);
        half  addAtten  = (half)(addLight.distanceAttenuation * addLight.shadowAttenuation);
        half  addArea   = GetShadowArea(addNdotL, addAtten);
        half  addFactor = GetCelShadingSmooth(addArea, (half)_ShadowThreshold, (half)_ShadowSmoothness);
        addDiffuse += addFactor * (half3)addLight.color;
    }
    finalColor += (float3)(saturate(addDiffuse) * (half3)albedo.rgb);

    // ── Rim Shade ─────────────────────────────────────────────────────────────
    if (_UseRimShade > 0.5)
    {
        half rimShadeMask = GetRimShade(
            (half3)N, (half3)V, (half3)L,
            (half)_RimShadePower,
            (half)_RimShadeThreshold, (half)_RimShadeSmoothness,
            (half)_RimShadeIntensity
        );
        finalColor = lerp(finalColor, finalColor * (float3)_RimShadeColor.rgb, (float)rimShadeMask);
    }

    // ── Debug Output (테스트 캔버스 시각화) ───────────────────────────────────
    if (_DebugMode > 0.5 && _DebugMode < 1.5)
        return float4(shadowFactor.xxx, 1.0);   // 1: Shadow Factor (흑백)
    if (_DebugMode > 1.5 && _DebugMode < 2.5)
        return float4(N * 0.5 + 0.5, 1.0);      // 2: World Normal (RGB, 버텍스 노멀)

    return float4(finalColor, albedo.a);
}

#endif // FEEL_HAIR_FRAGMENT_INCLUDED
