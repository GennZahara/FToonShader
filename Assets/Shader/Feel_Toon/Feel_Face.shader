Shader "Custom/Feel_Face"
{
    //  [얼굴 그림자 방식]
    //  [_USE_SDF_FACE OFF] 기본 NdotL Cel 셰이딩
    //  [_USE_SDF_FACE ON]  구 프록시 — 오브젝트 얼굴 메시가 독립 오브젝트여야 함.
    //                      얼굴에 맞는 구/원기둥에 빛을 쏘아서 그림자를 만드는 방식
    //  [_USE_SDF_FACE ON + _USE_SDF_TEX ON]
    //                      SDF 텍스처 — 메시 UV 기반 픽셀별 샘플링.
    //                      SDF 텍스처 베이크 시 얼굴 메시 UV와 반드시 일치시킬 것.

    Properties
    {
        // Base
        [MainColor] _BaseColor  ("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _MainTex  ("Main Texture", 2D) = "white" {}

        // Alpha Cutout (ForwardLit/ShadowCaster 공통)
        [Toggle] _UseAlphaClip  ("Use Alpha Clip", Float) = 0
        _Cutoff                 ("Alpha Cutoff", Range(0, 1)) = 0.5

        // Face Shadow
        // [OFF]            기본 NdotL Cel 셰이딩
        // [ON]             구 프록시 — 오브젝트 기준 픽셀별 구/원기둥 노멀
        // [ON + SDF Tex]   SDF 텍스처 — 메시 UV 픽셀별 샘플링
        [Toggle(_USE_SDF_FACE)] _UseSdfFace ("Use SDF Face Shadow", Float) = 0
        [Toggle(_USE_SDF_TEX)]  _UseSdfTex  ("+ SDF Texture", Float) = 0
        [Toggle]                _UseSdfDual ("+ R/G Dual Map (미러 없음, 기본 OFF=B+미러)", Float) = 0
        _SDFTexture             ("SDF Texture", 2D) = "white" {}
        // _SphereBlend 는 더 이상 사용되지 않음(기능 제거). .mat 호환성을 위해 Property 만 유지.
        [HideInInspector] _SphereBlend ("Sphere Blend (unused)", Range(0, 1)) = 1.0
        _ShadowThreshold        ("Shadow Threshold", Range(0, 1)) = 0.5
        _ShadowSoftness         ("Shadow Softness", Range(0.01, 0.5)) = 0.1
        _ShadowOffset           ("Shadow Offset", Range(-0.5, 0.5)) = 0.0

        // 1st Shadow
        [Toggle(_USE_SHADOW_1ST)] _UseShadow1st ("Use 1st Shadow", Float) = 0
        _ShadowTint             ("Shadow Tint Color", Color) = (0.6, 0.6, 0.9, 1)
        _ShadowStrength         ("Shadow Strength", Range(0, 1)) = 0.7

        // 2nd Shadow
        [Toggle(_USE_SHADOW_2ND)] _UseShadow2nd ("Use 2nd Shadow", Float) = 0
        _ShadowTint2            ("2nd Shadow Tint", Color) = (0.4, 0.4, 0.65, 1)
        _ShadowStrength2        ("2nd Shadow Strength", Range(0, 1)) = 0.8
        _Shadow2Threshold       ("2nd Shadow Threshold", Range(0, 1)) = 0.2
        _Shadow2Smoothness      ("2nd Shadow Smoothness", Range(0, 0.5)) = 0.05

        // Stylized SSS
        [Toggle(_USE_SSS)]      _UseSSS          ("Use SSS", Float) = 0
        _SSSColor               ("SSS Color", Color) = (1, 0.32, 0.18, 1)
        _SSSScale               ("SSS Scale", Range(0, 2)) = 1.0
        _SSSDistortion          ("SSS Distortion (투과 방향 왜곡)", Range(-1, 1)) = 0.4
        _GradientRange          ("Gradient Range (작을수록 날카로운 투과)", Range(0.01, 1)) = 0.3
        _GradientStrength       ("Gradient Strength (세기)", Range(0, 1)) = 0.7

        // Rim Light
        [Toggle(_USE_RIM_LIGHT)] _UseRimLight ("Use Rim Light", Float) = 0
        _RimColor               ("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower               ("Rim Power", Range(1, 10)) = 4.0
        _RimIntensity           ("Rim Intensity", Range(0, 2)) = 0.5

        // Rim Shade
        [Toggle(_USE_RIM_SHADE)] _UseRimShade ("Use Rim Shade", Float) = 0
        _RimShadeColor          ("Rim Shade Color",      Color)          = (0.1, 0.1, 0.2, 1)
        _RimShadePower          ("Rim Shade Power",      Range(0.1, 10)) = 3.0
        _RimShadeThreshold      ("Rim Shade Threshold",  Range(0, 1))    = 0.5
        _RimShadeSmoothness     ("Rim Shade Smoothness", Range(0, 0.5))  = 0.05
        _RimShadeIntensity      ("Rim Shade Intensity",  Range(0, 1))    = 0.5

        // MatCap
        [Toggle(_USE_MATCAP)] _UseMatCap ("Use MatCap", Float) = 0
        _MatCapTex              ("MatCap Texture", 2D) = "white" {}
        _MatCapColor            ("MatCap Color", Color) = (1, 1, 1, 1)
        _MatCapIntensity        ("MatCap Intensity", Range(0, 2)) = 0.5

        // Outline
        _OutlineColor           ("Outline Color", Color) = (0.15, 0.05, 0.1, 1)
        _OutlineWidth           ("Outline Width", Range(0.0, 3.0)) = 0.5

        // Debug Output — 중간 계산값 시각화 (테스트 캔버스용)
        [Enum(Off, 0, ShadowFactor, 1, Normal, 2, SDF, 3)] _DebugMode ("Debug Mode", Float) = 0

        // Stencil — 기본값은 비활성(Comp=Always, Pass=Keep, Ref=0) → 스텐실 안 쓰는 것과 동일
        [IntRange]                                    _StencilRef       ("Ref",       Range(0, 255)) = 0
        [IntRange]                                    _StencilReadMask  ("ReadMask",  Range(0, 255)) = 255
        [IntRange]                                    _StencilWriteMask ("WriteMask", Range(0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp      ("Comp",      Float)        = 8
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilPass      ("Pass",      Float)        = 0
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilFail      ("Fail",      Float)        = 0
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilZFail     ("ZFail",     Float)        = 0

        // Render State 오버라이드 — FaceMask 전용, 스크립트로 설정 (인스펙터에 노출 안 함)
        [HideInInspector] _Cull     ("Cull",      Float) = 2
        [HideInInspector] _ZTest    ("ZTest",     Float) = 4
        [HideInInspector] _ZWrite   ("ZWrite",    Float) = 1
        [HideInInspector] _SrcBlend ("Src Blend", Float) = 1
        [HideInInspector] _DstBlend ("Dst Blend", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType"     = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Geometry"
        }

        // ForwardLit Pass
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Stencil
            {
                Ref       [_StencilRef]
                ReadMask  [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Comp      [_StencilComp]
                Pass      [_StencilPass]
                Fail      [_StencilFail]
                ZFail     [_StencilZFail]
            }

            Cull [_Cull]
            ZWrite [_ZWrite]
            ZTest [_ZTest]
            Blend [_SrcBlend] [_DstBlend]

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            // 기능 토글 — UI 컨트롤러가 _UseX float으로 분기 (런타임 변경)

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            #pragma vertex   FeelVertex
            #pragma fragment FeelFaceFragment

            #include "Feel_Vertex.hlsl"
            #include "Feel_FaceFragment.hlsl"

            ENDHLSL
        }

        // Outline Pass — 커스텀 LightMode "FeelOutline"으로 Renderer Feature가 실행
        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "FeelOutline" }

            Stencil
            {
                Ref       [_StencilRef]
                ReadMask  [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Comp      [_StencilComp]
                Pass      [_StencilPass]
                Fail      [_StencilFail]
                ZFail     [_StencilZFail]
            }

            Cull  Front
            ZWrite On
            ZTest LEqual
            Offset 1, 1

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            #pragma vertex   OutlineVertex
            #pragma fragment OutlineFragment

            #include "Feel_FaceFragment.hlsl"
            #include "Feel_Outline.hlsl"

            ENDHLSL
        }

        // ShadowCaster Pass
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            Cull Back
            ZWrite On
            ZTest LEqual
            ColorMask 0

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex   FeelFaceShadowVertex
            #pragma fragment FeelFaceShadowFragment

            #include "Feel_FaceFragment.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct FaceShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;   // 알파 컷아웃 샘플링용
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct FaceShadowVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            FaceShadowVaryings FeelFaceShadowVertex(FaceShadowAttributes input)
            {
                FaceShadowVaryings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.uv = input.uv;

                float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
                float3 normalWS   = TransformObjectToWorldNormal(input.normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDir = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDir = _LightDirection;
                #endif

                output.positionCS = TransformWorldToHClip(
                    ApplyShadowBias(positionWS, normalWS, lightDir));

                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return output;
            }

            half4 FeelFaceShadowFragment(FaceShadowVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                float alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                  TRANSFORM_TEX(input.uv, _MainTex)).a * _BaseColor.a;
                FeelAlphaClip(alpha, _UseAlphaClip, _Cutoff);
                return 0;
            }

            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "FeelToon.ShaderInspector.FeelFaceShaderGUI"
}
