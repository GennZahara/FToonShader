Shader "Custom/Feel_Eye"
{
    Properties
    {
        // Base
        [MainColor] _BaseColor  ("Base Color", Color) = (1, 1, 1, 1)
        [MainTexture] _MainTex  ("Main Texture", 2D) = "white" {}

        // Alpha Cutout (ForwardLit/ShadowCaster/DepthOnly 공통)
        [Toggle] _UseAlphaClip  ("Use Alpha Clip", Float) = 0
        _Cutoff                 ("Alpha Cutoff", Range(0, 1)) = 0.5

        // Cel Shading
        [Toggle(_USE_RAMP_TEX)] _UseRampTex ("Use Ramp Texture", Float) = 0
        _RampTexture            ("Ramp Texture", 2D) = "white" {}
        [Toggle(_USE_FLOOR)]    _UseFloor   ("Use Floor Quantization", Float) = 0
        _CelSteps               ("Cel Steps", Range(2, 8)) = 2

        // 1st Shadow
        [Toggle(_USE_SHADOW_1ST)] _UseShadow1st ("Use 1st Shadow", Float) = 0
        _ShadowTint             ("Shadow Tint Color", Color) = (0.6, 0.6, 0.9, 1)
        _ShadowStrength         ("Shadow Strength", Range(0, 1)) = 0.7
        _ShadowThreshold        ("Shadow Threshold", Range(0, 1)) = 0.5
        _ShadowSmoothness       ("Shadow Smoothness", Range(0, 0.5)) = 0.1

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

        // Specular
        [Toggle(_USE_SPECULAR)] _UseSpecular ("Use Specular", Float) = 0
        _SpecularSize           ("Specular Size", Float) = 50.0
        _SpecularSmoothness     ("Specular Smoothness", Range(0, 0.5)) = 0.05
        _SpecularColor          ("Specular Color", Color) = (1, 1, 1, 1)
        _SpecularIntensity      ("Specular Intensity", Range(0, 2)) = 0.5

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

        // Normal Map
        [Toggle] _UseNormalMap ("Use Normal Map", Float) = 0
        [Normal] _NormalMap         ("Normal Map", 2D) = "bump" {}
        _ShadowNormalStrength       ("Shadow Normal Strength", Range(0, 1)) = 0.3

        // Parallax Mapping — URP 내장 1-sample Offset Parallax.
        // ParallaxMap.G 채널을 height로 읽음 (white=top, black=bottom).
        [Toggle(_USE_PARALLAX)] _UseParallax ("Use Parallax", Float) = 0
        _ParallaxMap              ("Parallax / Height Map (G ch)", 2D) = "white" {}
        _Parallax                 ("Parallax Strength", Range(0, 1)) = 0.02
        [Toggle] _ParallaxClampUV ("Clamp UV", Float) = 1

        // MatCap
        [Toggle(_USE_MATCAP)] _UseMatCap ("Use MatCap", Float) = 0
        _MatCapTex              ("MatCap Texture", 2D) = "white" {}
        _MatCapColor            ("MatCap Color", Color) = (1, 1, 1, 1)
        _MatCapIntensity        ("MatCap Intensity", Range(0, 2)) = 0.5

        // Stencil
        [IntRange]                                    _StencilRef       ("Ref",       Range(0, 255)) = 0
        [IntRange]                                    _StencilReadMask  ("ReadMask",  Range(0, 255)) = 255
        [IntRange]                                    _StencilWriteMask ("WriteMask", Range(0, 255)) = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp      ("Comp",      Float)        = 8
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilPass      ("Pass",      Float)        = 0
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilFail      ("Fail",      Float)        = 0
        [Enum(UnityEngine.Rendering.StencilOp)]       _StencilZFail     ("ZFail",     Float)        = 0

        // Stencil (See Through Pass) — 인스펙터에서 숨김.
        // bit0=Eye, bit1=Hair, bit2=어두운 마스크(Eye_Shadow/Lash_Brow).
        // 기본값 (Ref=3, RM=7): bit0&bit1 + bit2=0인 픽셀에서만 그림 (홍채/흰자/하이라이트).
        // Eye_Shadow/Lash_Brow는 머티리얼 측에서 Ref=7로 오버라이드 → 자기 영역에서 그림.
        [HideInInspector] _StencilRefSeeThrough      ("Ref (SeeThrough)",      Float) = 3
        [HideInInspector] _StencilReadMaskSeeThrough ("ReadMask (SeeThrough)", Float) = 7

        // See Through
        [Toggle(_USE_SEE_THROUGH)] _UseSeeThrough ("Use See Through", Float) = 1
        _SeeThroughAlpha      ("See Through Alpha", Range(0, 1)) = 0.5

        // Surface — 기본 불투명. Eye_Shadow 같은 반투명 오버레이는 SrcAlpha/OneMinusSrcAlpha + ZWrite Off로 설정.
        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("Src Blend", Float) = 1   // One
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("Dst Blend", Float) = 0   // Zero
        [Enum(Off, 0, On, 1)]                   _ZWrite   ("ZWrite", Float) = 1

        // Debug Output — 중간 계산값 시각화 (테스트 캔버스용)
        [Enum(Off, 0, ShadowFactor, 1, Normal, 2, SDF, 3)] _DebugMode ("Debug Mode", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderType"     = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Geometry"
        }

        // ── ForwardLit Pass ───────────────────────────────────────────────────
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            Cull Back
            ZWrite [_ZWrite]
            ZTest LEqual
            Blend [_SrcBlend] [_DstBlend]

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

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            // 기능 토글은 전부 _UseX uniform float 분기 (런타임 변경, 변종 컴파일 없음)
            // Normal Map 포함 — shader_feature 미사용으로 토글 시 프레임 히치 없음

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            #pragma vertex   FeelVertex
            #pragma fragment FeelEyeFragment

            #include "Feel_Vertex.hlsl"
            #include "Feel_EyeFragment.hlsl"

            ENDHLSL
        }

        // ── SeeThrough Pass ───────────────────────────────────────────────────
        // FeelSeeThroughRendererFeature 에 의해 AfterRenderingOpaques에서 실행.
        // stencil 비교는 머티리얼 프로퍼티 (_StencilRefSeeThrough / _StencilReadMaskSeeThrough)로 분기.
        Pass
        {
            Name "SeeThrough"
            Tags { "LightMode" = "FeelSeeThrough" }

            Cull Back
            ZTest Greater
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            Stencil
            {
                Ref      [_StencilRefSeeThrough]
                ReadMask [_StencilReadMaskSeeThrough]
                Comp     Equal
                Pass     Keep
            }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma multi_compile_instancing

            // 기능 토글은 전부 _UseX uniform float 분기 (런타임 변경, 변종 컴파일 없음)
            // Normal Map 포함 — shader_feature 미사용으로 토글 시 프레임 히치 없음

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS

            #pragma vertex   FeelVertex
            #pragma fragment FeelEyeSeeThroughFragment

            #include "Feel_Vertex.hlsl"
            #include "Feel_EyeFragment.hlsl"

            ENDHLSL
        }

        // ── ShadowCaster Pass ─────────────────────────────────────────────────
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

            #pragma vertex   EyeShadowVertex
            #pragma fragment EyeShadowFragment

            #include "Feel_EyeFragment.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            float3 _LightDirection;
            float3 _LightPosition;

            struct EyeShadowAttributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
                float2 uv         : TEXCOORD0;   // 알파 컷아웃 샘플링용
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct EyeShadowVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            EyeShadowVaryings EyeShadowVertex(EyeShadowAttributes input)
            {
                EyeShadowVaryings output;
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

            half4 EyeShadowFragment(EyeShadowVaryings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                float alpha = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex,
                                  TRANSFORM_TEX(input.uv, _MainTex)).a * _BaseColor.a;
                FeelAlphaClip(alpha, _UseAlphaClip, _Cutoff);
                return 0;
            }

            ENDHLSL
        }

        // ── DepthOnly Pass ────────────────────────────────────────────────────
        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask R
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex EyeDepthVertex
            #pragma fragment EyeDepthFragment
            #pragma multi_compile_instancing

            #include "Feel_EyeFragment.hlsl"

            struct EyeDepthAttributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;   // 알파 컷아웃 샘플링용
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct EyeDepthVaryings
            {
                float4 positionCS : SV_POSITION;
                float2 uv         : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            EyeDepthVaryings EyeDepthVertex(EyeDepthAttributes input)
            {
                EyeDepthVaryings output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.uv = input.uv;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                return output;
            }

            half4 EyeDepthFragment(EyeDepthVaryings input) : SV_Target
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
    CustomEditor "FeelToon.ShaderInspector.FeelEyeShaderGUI"
}
