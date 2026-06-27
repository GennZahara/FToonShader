#ifndef FEEL_EYE_FRAGMENT_INCLUDED
#define FEEL_EYE_FRAGMENT_INCLUDED

//  Feel_EyeFragment.hlsl — Feel_Eye.shader 전용 Fragment
//
//  Feel_Main 대비 제외 항목:
//    - Light Map         (눈 영역에 베이크 맵 불필요)
//    - Kajiya-Kay        (헤어 전용)
//    - SDF Face Shadow   (Face 전용)
//    - Outline Pass      (눈에 아웃라인 미사용)
//
//  추가 항목: Parallax Mapping
//    - Off    : 비활성
//    - Simple : URP 내장 1-sample Offset Parallax (ParallaxMapping)

#include "Feel_Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ParallaxMapping.hlsl"
#include "Feel_Functions.hlsl"


// ── 텍스처 ────────────────────────────────────────────────────────────────────
TEXTURE2D(_MainTex);     SAMPLER(sampler_MainTex);
TEXTURE2D(_RampTexture); SAMPLER(sampler_RampTexture);
TEXTURE2D(_NormalMap);   SAMPLER(sampler_NormalMap);
TEXTURE2D(_MatCapTex);   SAMPLER(sampler_MatCapTex);
TEXTURE2D(_ParallaxMap); SAMPLER(sampler_ParallaxMap);


// ── CBUFFER — Feel_Eye.shader 전용 ───────────────────────────────────────────
CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    float4 _RampTexture_ST;
    float4 _NormalMap_ST;
    float4 _ParallaxMap_ST;
    float4 _BaseColor;

    // Alpha Cutout
    float  _Cutoff;

    // Normal Map
    float  _ShadowNormalStrength;

    // Parallax Mapping
    float  _Parallax;
    float  _ParallaxClampUV;

    // Cel Shading
    float  _CelSteps;
    float  _ShadowThreshold;
    float  _ShadowSmoothness;

    // 1st Shadow
    float4 _ShadowTint;
    float  _ShadowStrength;

    // 2nd Shadow
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
    float  _UseParallax;
    float  _UseSeeThrough;
    float  _UseAlphaClip;

    // Stencil (SRP Batcher 규정 — render state 참조용)
    float  _StencilRef;
    float  _StencilReadMask;
    float  _StencilWriteMask;
    float  _StencilComp;
    float  _StencilPass;
    float  _StencilFail;
    float  _StencilZFail;
    float  _StencilRefSeeThrough;
    float  _StencilReadMaskSeeThrough;

    // Surface (render state 참조용)
    float  _SrcBlend;
    float  _DstBlend;
    float  _ZWrite;

    // See Through
    float  _SeeThroughAlpha;
    // Debug Output (0=Off, 1=ShadowFactor, 2=Normal, 3=SDF)
    float  _DebugMode;

CBUFFER_END


// ── Fragment ──────────────────────────────────────────────────────────────────
float4 FeelEyeFragment(Varyings input) : SV_Target
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // ── 벡터 계산 ────────────────────────────────────────────────────────────
    float3 N_vertex = normalize(input.normalWS);
    float3 V        = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));

    float2 uv = TRANSFORM_TEX(input.uv, _MainTex);

    // ── Parallax Mapping ─────────────────────────────────────────────────────
    // Simple: URP 내장 1-sample Offset Parallax. offset을 _MainTex/_NormalMap UV에
    // 동일하게 적용 (눈 메시는 같은 UV space 가정).
    float2 parallaxOffset = float2(0.0, 0.0);
    if (_UseParallax > 0.5)
    {
        half3 T_TS      = normalize(input.tangentWS);
        half3 B_TS      = normalize(input.bitangentWS);
        half3 viewDirTS = mul(half3x3(T_TS, B_TS, (half3)N_vertex), (half3)V);

        parallaxOffset = ParallaxMapping(
            TEXTURE2D_ARGS(_ParallaxMap, sampler_ParallaxMap),
            viewDirTS, (half)_Parallax, uv);

        uv += parallaxOffset;

        // ClampUV: UV가 [0,1] 밖이면 discard (눈 메시 가장자리 누수 방지)
        if (_ParallaxClampUV > 0.5 &&
            (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0))
        {
            discard;
        }
    }

    // N_full: RimLight/Specular/MatCap용, N_cel: 셀 경계 보호용
    // (uniform float 분기 — 런타임 토글 시 변종 컴파일 없음)
    float3 N_full = N_vertex;
    float3 N_cel  = N_vertex;
    if (_UseNormalMap > 0.5)
    {
        N_full = (float3)GetNormalFromMap(
            TEXTURE2D_ARGS(_NormalMap, sampler_NormalMap),
            TRANSFORM_TEX(input.uv, _NormalMap) + parallaxOffset,
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

    // ── Shadow Factor (Cel Shading) ───────────────────────────────────────────
    half rawNdotL   = (half)dot(N_cel, L);
    half shadowArea = GetShadowArea(rawNdotL, (half)atten);

    half shadowFactor;
    if (_UseRampTex > 0.5)
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

    // ── Specular (Blinn-Phong) ────────────────────────────────────────────────
    if (_UseSpecular > 0.5)
    {
        half specHighlight = ToonSpecular(
            (half3)N_full, (half3)V, (half3)L,
            (half)_SpecularSize, (half)_SpecularSmoothness
        );
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
    if (_UseRimLight > 0.5)
    {
        half3 rimContrib = GetRimLight(
            (half3)N_full, (half3)V,
            (half3)_RimColor.rgb,
            (half)_RimPower, (half)_RimIntensity
        );
        finalColor = 1.0 - (1.0 - finalColor) * (1.0 - (float3)rimContrib);
    }

    // ── MatCap ────────────────────────────────────────────────────────────────
    if (_UseMatCap > 0.5)
    {
        finalColor += (float3)GetMatCap(
            TEXTURE2D_ARGS(_MatCapTex, sampler_MatCapTex),
            (half3)N_full,
            (half3)_MatCapColor.rgb, (half)_MatCapIntensity, shadowFactor
        );
    }

    // ── Additional Lights ─────────────────────────────────────────────────────
    //  광원별 cel diffuse를 누적한 뒤 saturate로 합을 클램프 → 다중 포인트라이트 블로우아웃 방지.
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
        return float4(N_full * 0.5 + 0.5, 1.0);  // 2: World Normal (RGB, 노멀맵+패럴랙스 반영)

    return float4(finalColor, albedo.a);
}


// ── SeeThrough Pass Fragment ──────────────────────────────────────────────────
//  ForwardLit에서 Eye가 bit0, Hair가 bit1, Lash_Brow/Eye_Shadow가 추가로 bit2.
//  stencil 비교는 머티리얼 프로퍼티(_StencilRef/ReadMaskSeeThrough)로 분기.
//  _SeeThroughAlpha만 알파로 사용 — 텍스처 알파에 의존하지 않음
//  (Lash_Brow처럼 검정 atlas 텍스처 알파가 낮은 영역에서도 보이도록).
//  _UseSeeThrough OFF일 때는 픽셀을 discard해 머티리얼 단위로 SeeThrough 차단.
float4 FeelEyeSeeThroughFragment(Varyings input) : SV_Target
{
    if (_UseSeeThrough < 0.5)
        discard;

    float4 color = FeelEyeFragment(input);
    color.a *= _SeeThroughAlpha;
    return color;
}


#endif // FEEL_EYE_FRAGMENT_INCLUDED
