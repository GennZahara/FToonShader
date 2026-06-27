#ifndef FEEL_FACE_FRAGMENT_INCLUDED
#define FEEL_FACE_FRAGMENT_INCLUDED

//  Feel_FaceFragment.hlsl — 얼굴 전용 Fragment
//  Face,Hair,Main 각각 프로퍼티가 다르니까 그에 맞게 CBuffer를 선언해야 하는데
//  하나에 다 선언하면 불필요한게 노출되거나, 비효율적으로 작동
//  렌더링 파이프라인:
//    Albedo × BaseColor
//      → Face Shadow (NdotL 또는 SDF 기반)
//          → SSS
//            → RimLight
//
//  [Face Shadow 경로]
//    _USE_SDF_FACE OFF → 기본 NdotL Cel 셰이딩 (shadowAttenuation 제외)
//    _USE_SDF_FACE ON  → 구 프록시 (코드 기반, C# 불필요)
//    _USE_SDF_FACE ON + _USE_SDF_TEX ON → SDF 텍스처 기반
// ============================================================================

#include "Feel_Input.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Feel_Functions.hlsl"


// 텍스처 (Main이랑, SDF)
TEXTURE2D(_MainTex);    SAMPLER(sampler_MainTex);
TEXTURE2D(_SDFTexture); SAMPLER(sampler_SDFTexture);
TEXTURE2D(_MatCapTex);  SAMPLER(sampler_MatCapTex);


// ── CBUFFER — Feel_Face.shader 전용 ──────────────────────────────────────────.
CBUFFER_START(UnityPerMaterial)
    //기본적인 텍스쳐와 색상
    float4 _MainTex_ST;
    float4 _SDFTexture_ST;
    float4 _BaseColor;

    // Alpha Cutout
    float  _Cutoff;

    // Face Shadow
    float  _ShadowThreshold;
    float  _ShadowSoftness;
    float  _ShadowOffset;
    float  _SphereBlend;

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

    // MatCap
    float4 _MatCapColor;
    float  _MatCapIntensity;

    // Outline (Outline Pass에서도 CBUFFER 일관성 유지)
    float4 _OutlineColor;
    float  _OutlineWidth;

    // Toggle floats — SRP Batcher 규칙
    float  _UseSdfFace;
    float  _UseSdfTex;
    float  _UseSdfDual;
    float  _UseShadow1st;
    float  _UseShadow2nd;
    float  _UseSSS;
    float  _UseRimLight;
    float  _UseRimShade;
    float  _UseMatCap;
    float  _UseAlphaClip;

    // Stencil + Render State (SRP Batcher 규정 — render state 참조용, HLSL에서는 미사용)
    float  _StencilRef;
    float  _StencilReadMask;
    float  _StencilWriteMask;
    float  _StencilComp;
    float  _StencilPass;
    float  _StencilFail;
    float  _StencilZFail;
    float  _Cull;
    float  _ZTest;
    float  _ZWrite;
    float  _SrcBlend;
    float  _DstBlend;
    // Debug Output (0=Off, 1=ShadowFactor, 2=Normal, 3=SDF)
    float  _DebugMode;

CBUFFER_END


// Fragment 함수

float4 FeelFaceFragment(Varyings input) : SV_Target
{
    //인스턴스 설정
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    // 벡터 계산 
    float3 N = normalize(input.normalWS);
    float3 V = normalize(GetWorldSpaceNormalizeViewDir(input.positionWS));

    // 메인 라이트(Unity Light.hlsl에 있음)
    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
    Light  mainLight   = GetMainLight(shadowCoord);
    float3 L           = normalize(mainLight.direction);

    // 거리 감쇠(distanceAttenuation)만 라이트 계산에 반영.
    float  distAtten  = mainLight.distanceAttenuation;
    float3 lightColor = mainLight.color * distAtten;

    // uv값
    float2 uv     = TRANSFORM_TEX(input.uv, _MainTex);
    float4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv) * _BaseColor;

    // Alpha Cutout — ShadowCaster 패스도 동일 기준으로 잘라 실루엣 일치
    FeelAlphaClip(albedo.a, _UseAlphaClip, _Cutoff);

    // raw NdotL (SSS 계산용 및 기본 face shadow)
    half rawNdotL = (half)dot(N, L);

    // ── Shadow Factor ─────────────────────────────────────────────────────────
    //  SDF raw 값을 꺼낸 뒤 1st/2nd threshold를 각각 적용.
    //  [기본 NdotL]  얼굴 노멀 Cel 셰이딩 (shadowAttenuation 제외)
    //  [Proxy]       구 프록시 raw area → smoothstep × 2
    //  [SDF Texture] sdfValue + angleThreshold → smoothstep × 2

    half shadowFactor;
    // 외부 스코프 변수: 2nd Shadow에서 재사용 위해
    half sdfValue        = 0.0h;
    half angleThreshold  = 0.5h;
    half threshold1_sdf  = 0.5h;   // SDF Texture 1st 임계점 (2nd 기준)
    half proxyArea       = 0.0h;

    if (_UseSdfFace > 0.5)
    {
        if (_UseSdfTex > 0.5)
        {
            // SDF Texture 모드: 베이크된 텍스처 + 빛 각도 기반 임계점.
            // _ShadowThreshold(0~1)는 0.5 기준 bias로 angleThreshold를 평행 이동.
            GetFaceShadowData_SDF(
                (half3)L, input.uv,
                (half)_ShadowOffset, (half)_UseSdfDual,
                _SDFTexture, sampler_SDFTexture,
                sdfValue, angleThreshold
            );
            half soft1_sdf = max((half)_ShadowSoftness, 0.001h);
            threshold1_sdf = saturate(angleThreshold + ((half)_ShadowThreshold - 0.5h));
            shadowFactor = smoothstep(
                saturate(threshold1_sdf - soft1_sdf),
                saturate(threshold1_sdf + soft1_sdf),
                sdfValue
            );
        }
        else
        {
            // Proxy 모드: 구/원기둥 프록시 only. _ShadowThreshold가 직접 임계점.
            proxyArea = GetFaceShadowArea_Proxy(
                input.positionWS, (half3)L, (half)_ShadowOffset
            );
            half soft1_proxy   = max((half)_ShadowSoftness, 0.001h);
            half threshold1_px = saturate((half)_ShadowThreshold);
            shadowFactor = smoothstep(
                saturate(threshold1_px - soft1_proxy * 0.5h),
                saturate(threshold1_px + soft1_proxy * 0.5h),
                proxyArea
            );
        }
        shadowFactor *= (half)distAtten;
    }
    else
    {
        // NdotL 모드: 기본 얼굴 노멀 Cel 셰이딩
        half shadowArea = GetShadowArea(rawNdotL, (half)distAtten);
        shadowFactor = GetCelShadingSmooth(
            shadowArea,
            (half)(_ShadowThreshold + _ShadowOffset),
            (half)_ShadowSoftness
        );
    }

    // ── 2nd Shadow Factor ─────────────────────────────────────────────────────
    //  1st Shadow의 임계점 기준으로 _Shadow2Threshold만큼 더 어두운 쪽으로 분리.
    half shadowFactor2 = 1.0;
    if (_UseShadow2nd > 0.5)
    {
        if (_UseSdfFace > 0.5)
        {
            if (_UseSdfTex > 0.5)
            {
                // SDF Texture: threshold1_sdf 기준으로 shadowGap만큼 더 어둡게
                half soft2_sdf      = max((half)_Shadow2Smoothness, 0.001h);
                half shadowGap      = 0.5h - (half)_Shadow2Threshold;
                half threshold2_sdf = saturate(threshold1_sdf - shadowGap);
                shadowFactor2 = smoothstep(
                    saturate(threshold2_sdf - soft2_sdf),
                    saturate(threshold2_sdf + soft2_sdf),
                    sdfValue
                );
            }
            else
            {
                // Proxy: proxyArea 재활용
                shadowFactor2 = GetCelShadingSmooth(
                    proxyArea, (half)_Shadow2Threshold, (half)_Shadow2Smoothness
                );
            }
        }
        else
        {
            // NdotL 모드
            half shadowArea2 = GetShadowArea(rawNdotL, 1.0h);
            shadowFactor2 = GetCelShadingSmooth(
                shadowArea2, (half)_Shadow2Threshold, (half)_Shadow2Smoothness
            );
        }
    }

    float3 albedoRGB = (float3)albedo.rgb;

    //기존 Shadow Tint
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
        float3 shadowMix    = lerp(shadow2Color, shadowColor, (float)shadowFactor2);
        finalColor          = lerp(shadowMix, litColor, (float)shadowFactor);
    }
    else
    {
        finalColor = lerp(shadowColor, litColor, (float)shadowFactor);
    }

    // ── Ambient (SH) — 환경광 채우기 (Ambient Intensity 슬라이더로 제어, 그림자도 들어올림)
    finalColor += albedoRGB * max((float3)0.0, (float3)input.vertexSH);

    // Stylized SSS
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
    //  Screen Blend: 1-(1-A)(1-B) — 블로우아웃 방지
    if (_UseRimLight > 0.5)
    {
        half3 rimContrib = GetRimLight(
            (half3)N, (half3)V,
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
            (half3)N,
            (half3)_MatCapColor.rgb, (half)_MatCapIntensity, shadowFactor
        );
    }

    // ── Additional Lights 루프 ────────────────────────────────────────────────
    //  SDF face shadow는 메인 라이트 전용 효과 — Additional Light는 일반 NdotL Cel로 처리.
    //  (Main/Eye/Hair와 동일 패턴, _ShadowSoftness만 Face 명명 그대로 사용)
    //  광원별 cel diffuse를 누적한 뒤 saturate로 합을 클램프 → 다중 포인트라이트 블로우아웃 방지.
    uint  additionalLightCount = GetAdditionalLightsCount();
    half3 addDiffuse           = 0.0h;
    for (uint i = 0u; i < additionalLightCount; i++)
    {
        Light addLight  = GetAdditionalLight(i, input.positionWS);
        half  addNdotL  = (half)dot(N, addLight.direction);
        half  addAtten  = (half)(addLight.distanceAttenuation * addLight.shadowAttenuation);
        half  addArea   = GetShadowArea(addNdotL, addAtten);
        half  addFactor = GetCelShadingSmooth(addArea, (half)_ShadowThreshold, (half)_ShadowSoftness);
        addDiffuse += addFactor * (half3)addLight.color;
    }
    finalColor += (float3)(saturate(addDiffuse) * (half3)albedo.rgb);

    // ── Rim Shade ─────────────────────────────────────────────────────────────
    //  모든 Additive 연산(SSS/RimLight/MatCap/AdditionalLights) 이후 마지막 Multiply.
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
    if (_DebugMode > 2.5 && _DebugMode < 3.5)
    {
        // 3: SDF — 그림자 판정에 쓰인 raw 값(흑백) + 현재 임계점 컨투어
        //    빨강 = 1st Shadow 경계, 파랑 = 2nd Shadow 경계 (2nd ON일 때만)
        //    라이트를 돌리면 경계선이 얼굴 위를 쓸고 지나가는 모습으로 SDF 품질 검증.
        //    경로별 값/임계점은 위 Shadow Factor 계산과 동일한 기준 사용.
        half debugValue;
        half debugThr1;
        half debugThr2;
        if (_UseSdfFace > 0.5 && _UseSdfTex > 0.5)
        {
            // SDF Texture: 거리값 vs 빛 각도 임계점
            debugValue = sdfValue;
            debugThr1  = threshold1_sdf;
            debugThr2  = saturate(threshold1_sdf - (0.5h - (half)_Shadow2Threshold));
        }
        else if (_UseSdfFace > 0.5)
        {
            // Proxy: 구 표면 half-lambert vs 고정 임계점
            debugValue = saturate(proxyArea);
            debugThr1  = saturate((half)_ShadowThreshold);
            debugThr2  = saturate((half)_Shadow2Threshold);
        }
        else
        {
            // NdotL: 기본 셀 셰이딩과 동일한 area/임계점
            debugValue = GetShadowArea(rawNdotL, (half)distAtten);
            debugThr1  = saturate((half)(_ShadowThreshold + _ShadowOffset));
            debugThr2  = saturate((half)_Shadow2Threshold);
        }

        // 컨투어 폭: 화면 공간 기준 일정하게 (fwidth), 최소폭 보장
        // (_DebugMode/_UseSdf*는 uniform이라 이 분기 내 derivative 사용 안전)
        half lineW = max((half)fwidth((float)debugValue) * 1.5h, 0.004h);

        float3 debugColor = (float3)debugValue.xxx;
        if (_UseShadow2nd > 0.5 && abs(debugValue - debugThr2) < lineW)
            debugColor = float3(0.2, 0.4, 1.0);
        if (abs(debugValue - debugThr1) < lineW)
            debugColor = float3(1.0, 0.15, 0.1);
        return float4(debugColor, 1.0);
    }

    return float4(finalColor, albedo.a);
}


#endif // FEEL_FACE_FRAGMENT_INCLUDED
