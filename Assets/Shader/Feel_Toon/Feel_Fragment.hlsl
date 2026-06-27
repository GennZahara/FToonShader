#ifndef FEEL_FRAGMENT_INCLUDED
#define FEEL_FRAGMENT_INCLUDED

//  Feel_Fragment.hlsl — Feel_Main.shader 전용 Fragment

//  CBUFFER(UnityPerMaterial) + 텍스처 선언.

//  렌더링 파이프라인 (NPR Two-Tone):
//    Albedo × BaseColor
//      → CelShading (Ramp 또는 Smoothstep) → shadowFactor
//        → shadowColor = albedo × shadowTintMul  (씬 앰비언트와 무관한 고정 색상)
//          litColor    = albedo × lightColor
//          finalColor  = lerp(shadowColor, litColor, shadowFactor)
//            → SSS (역광 반투과, Additive)
//              → RimLight (Fresnel 실루엣, Additive)

#include "Feel_Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Feel_Functions.hlsl"


// ── 텍스처 ────────────────────────────────────────────────────────────────────
//텍스쳐와 라이트맵
TEXTURE2D(_MainTex);     SAMPLER(sampler_MainTex);
TEXTURE2D(_RampTexture); SAMPLER(sampler_RampTexture);
TEXTURE2D(_LightMap);    SAMPLER(sampler_LightMap);
TEXTURE2D(_NormalMap);   SAMPLER(sampler_NormalMap);
TEXTURE2D(_MatCapTex);   SAMPLER(sampler_MatCapTex);


// ── CBUFFER — Feel_Main.shader 전용 ──────────────────────────────────────────
CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _RampTexture_ST;
    float4 _NormalMap_ST;
    float4 _LightMap_ST;
    float4 _BaseColor;

    // Alpha Cutout
    float  _Cutoff;

    // Normal Map
    float  _ShadowNormalStrength;

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

    // Specular (Blinn-Phong)
    float  _SpecularSize;
    float  _SpecularSmoothness;
    float4 _SpecularColor;
    float  _SpecularIntensity;

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

    // MatCap
    float4 _MatCapColor;
    float  _MatCapIntensity;

    // Outline (Outline Pass에서도 CBUFFER 일관성 유지)
    float4 _OutlineColor;
    float  _OutlineWidth;

    // Toggle floats — SRP Batcher 규칙
    float  _UseRampTex;
    float  _UseFloor;
    float  _UseShadow1st;
    float  _UseShadow2nd;
    float  _UseSpecular;
    float  _UseSSS;
    float  _UseRimLight;
    float  _UseRimShade;
    float  _UseNormalMap;
    float  _UseMatCap;
    float  _UseLightMap;
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

float4 FeelFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // ── 벡터 계산 ────────────────────────────────────────────────────────────
    float3 N_vertex = normalize(input.normalWS);
    float3 V        = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));

    // UV는 노멀맵 샘플링에도 재사용하므로 먼저 계산
    float2 uv = TRANSFORM_TEX(input.uv, _MainTex);

    // Normal Map 분기 (uniform float — 런타임 토글 시 변종 컴파일 없음)
    //  N_full : 노멀맵 완전 적용  → RimLight, (추후 MatCap)에 사용
    //  N_cel  : vertex normal과 혼합 → 셀 경계 보호 목적
    float3 N_full = N_vertex;
    float3 N_cel  = N_vertex;
    if (_UseNormalMap > 0.5)
    {
        N_full = (float3)GetNormalFromMap(
            TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap),
            TRANSFORM_TEX(input.uv, _NormalMap),
            N_vertex,
            normalize(input.tangentWS),
            normalize(input.bitangentWS)
        );
        N_cel = normalize(lerp(N_vertex, N_full, _ShadowNormalStrength));
    }

    // ── 메인 라이트 ───────────────────────────────────────────────────────────
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light  mainLight   = GetMainLight(shadowCoord);
    float3 L           = normalize(mainLight.direction);

    float  atten      = mainLight.distanceAttenuation * mainLight.shadowAttenuation;
    float3 lightColor = mainLight.color * atten;

    // ── Albedo ────────────────────────────────────────────────────────────────
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * _BaseColor;

    // Alpha Cutout — ShadowCaster/DepthOnly 패스도 동일 기준으로 잘라 실루엣 일치
    FeelAlphaClip(albedo.a, _UseAlphaClip, _Cutoff);

    // ── Light Map 샘플링 ──────────────────────────────────────────────────────
    //  R: Shadow Threshold Map — 픽셀별 그림자 경계 (0=항상 밝음, 1=항상 그림자)
    //  G: Specular Mask
    //  B: Rim Light Mask
    half lmShadowThreshold = 0.5;
    half lmSpecMask        = 1.0;
    half lmRimMask         = 1.0;
    if (_UseLightMap > 0.5)
    {
        float2 lightMapUV     = TRANSFORM_TEX(input.uv, _LightMap);
        float4 lightMapSample = SAMPLE_TEXTURE2D(_LightMap, sampler_LightMap, lightMapUV);
        // R채널을 0.25~0.75 범위로 리매핑 — 극단값(항상 밝음/항상 어둠) 방지
        // Star Rail 원본 셰이더와 동일한 방식
        lmShadowThreshold = (half)(lightMapSample.r * 0.5 + 0.25);
        lmSpecMask        = (half)lightMapSample.g;
        lmRimMask         = (half)lightMapSample.b;
    }

    // raw NdotL (SSS 계산용, Half-Lambert 아님)
    // 셀 경계는 N_cel 기준 — vertex normal에 노멀맵을 _ShadowNormalStrength 비율로 블렌드
    half rawNdotL = (half)dot(N_cel, L);

    // ── Shadow Factor (Cel Shading) ───────────────────────────────────────────
    half shadowArea = GetShadowArea(rawNdotL, (half)atten);

    half shadowFactor;
    if (_UseLightMap > 0.5)
    {
        // LightMap R채널을 픽셀별 threshold로 사용 — 아티스트가 베이크한 경계 유지.
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
    //  Shadow zone: 아티스트 틴트 + 환경광(SH) 블렌딩
    //  Lit   zone:  albedo × 직접광
    //  lerp(shadowColor, litColor, shadowFactor) 로 경계 제어

    float3 albedoRGB = (float3)albedo.rgb;

    float3 shadowMul = (_UseShadow1st > 0.5)
        ? lerp(float3(1.0, 1.0, 1.0), (float3)_ShadowTint.rgb, _ShadowStrength)
        : float3(0.6, 0.62, 0.72);  // 기본 cool-gray

    float3 shadowColor = albedoRGB * shadowMul;
    float3 litColor    = albedoRGB * lightColor;

    // ── 합성 ─────────────────────────────────────────────────────────────────
    float3 finalColor;
    if (_UseShadow2nd > 0.5)
    {
        float3 shadow2Mul   = lerp(float3(1.0, 1.0, 1.0), (float3)_ShadowTint2.rgb, _ShadowStrength2);
        float3 shadow2Color = albedoRGB * shadow2Mul;
        // 3단계: 2nd shadow → 1st shadow → lit
        float3 shadowMix    = lerp(shadow2Color, shadowColor, (float)shadowFactor2);
        finalColor          = lerp(shadowMix, litColor, (float)shadowFactor);
    }
    else
    {
        finalColor = lerp(shadowColor, litColor, (float)shadowFactor);
    }

    // ── Ambient (SH) — 환경광 채우기 (Ambient Intensity 슬라이더로 제어, 그림자도 들어올림)
    finalColor += albedoRGB * max((float3)0.0, (float3)input.vertexSH);

    // ── Specular (Blinn-Phong, Hard-Edge) ────────────────────────────────────
    //  N_full 사용: 노멀맵 디테일이 스펙큘러 경계에 반영되도록.
    if (_UseSpecular > 0.5)
    {
        half specHighlight = ToonSpecular(
            (half3)N_full, (half3)V, (half3)L,
            (half)_SpecularSize, (half)_SpecularSmoothness
        );
        if (_UseLightMap > 0.5)
            specHighlight *= lmSpecMask;
        finalColor += (float3)(specHighlight * (half3)_SpecularColor.rgb
                               * (half)_SpecularIntensity * shadowFactor);
    }

    // ── Stylized SSS ──────────────────────────────────────────────────────────
    if (_UseSSS > 0.5)
    {
        finalColor += (float3)GetSSS(
            (half3)N_cel, (half3)L, (half3)V,
            (half3)_SSSColor.rgb, (half3)lightColor,
            (half)_SSSScale, (half)_SSSDistortion,
            (half)_GradientRange, (half)_GradientStrength
        );
    }

    // ── Rim Light ─────────────────────────────────────────────────────────────
    //  Screen Blend: 1-(1-A)(1-B) — Additive처럼 밝아지되 1.0에서 소프트클램프 → 블로우아웃 방지
    //  N_full 사용: 노멀맵 디테일이 실루엣에 완전히 반영되도록
    if (_UseRimLight > 0.5)
    {
        half3 rimContrib = GetRimLight(
            (half3)N_full, (half3)V,
            (half3)_RimColor.rgb,
            (half)_RimPower, (half)_RimIntensity
        );
        if (_UseLightMap > 0.5)
        {
            // LightMap B채널: 림라이트를 받을 부위만 선택적으로 강조
            rimContrib *= lmRimMask;
        }
        finalColor = 1.0 - (1.0 - finalColor) * (1.0 - (float3)rimContrib);
    }

    // ── MatCap ────────────────────────────────────────────────────────────────
    // N_full 사용: Normal Map On이면 노멀맵 디테일 반영, Off이면 N_vertex와 동일
    if (_UseMatCap > 0.5)
    {
        finalColor += (float3)GetMatCap(
            TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex),
            (half3)N_full,
            (half3)_MatCapColor.rgb, (half)_MatCapIntensity, shadowFactor
        );
    }

    // ── Additional Lights 루프 ────────────────────────────────────────────────
    //  광원별 cel diffuse를 누적한 뒤 saturate로 합을 클램프 → 다중 포인트라이트 블로우아웃 방지.
    //  albedo는 마지막에 한 번만 곱함 (광원마다 albedo 재가산하던 기존 방식이 과누적의 원인).
    uint  additionalLightCount = GetAdditionalLightsCount();
    half3 addDiffuse           = 0.0h;
    for (uint i = 0u; i < additionalLightCount; i++)
    {
        Light addLight  = GetAdditionalLight(i, input.positionWS);
        half  addNdotL  = (half)dot(N_cel, addLight.direction);
        half  addAtten  = (half)(addLight.distanceAttenuation * addLight.shadowAttenuation);
        half  addArea   = GetShadowArea(addNdotL, addAtten);
        half  addFactor = GetCelShadingSmooth(addArea, (half)_ShadowThreshold, (half)_ShadowSmoothness);
        addDiffuse += addFactor * (half3)addLight.color;
    }
    finalColor += (float3)(saturate(addDiffuse) * (half3)albedo.rgb);

    // ── Rim Shade ─────────────────────────────────────────────────────────────
    //  모든 Additive 연산(Specular/SSS/RimLight/MatCap/AdditionalLights) 이후 마지막 Multiply.
    //  최종 실루엣 전체를 어둡게 눌러주는 역할 — 앞의 Additive에 덮이지 않음.
    //  N_full 사용: RimLight와 동일한 실루엣 기준.
    if (_UseRimShade > 0.5)
    {
        half rimShadeMask = GetRimShade(
            (half3)N_full, (half3)V, (half3)L,
            (half)_RimShadePower,
            (half)_RimShadeThreshold, (half)_RimShadeSmoothness,
            (half)_RimShadeIntensity
        );
        finalColor = lerp(finalColor, finalColor * (float3)_RimShadeColor.rgb, (float)rimShadeMask);
    }

    // ── Debug Output (테스트 캔버스 시각화) ───────────────────────────────────
    if (_DebugMode > 0.5 && _DebugMode < 1.5)
        return float4(shadowFactor.xxx, 1.0);    // 1: Shadow Factor (흑백)
    if (_DebugMode > 1.5 && _DebugMode < 2.5)
        return float4(N_full * 0.5 + 0.5, 1.0);  // 2: World Normal (RGB, 노멀맵 반영)

    return float4(finalColor, albedo.a);
}


#endif // FEEL_FRAGMENT_INCLUDED
