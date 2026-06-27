using UnityEditor;
using UnityEngine;

namespace FeelToon.ShaderInspector
{
    public class FeelEyeShaderGUI : FeelShaderGUIBase
    {
        protected override void DrawSections()
        {
            DrawBigGroup("기본", () =>
            {
                Prop("_BaseColor");
                Tex("_MainTex");

                DrawSection("Cel Shading", null, () =>
                {
                    var useRamp = Find("_UseRampTex");
                    if (useRamp != null)
                    {
                        materialEditor.ShaderProperty(useRamp, useRamp.displayName);
                        using (new EditorGUI.DisabledScope(useRamp.floatValue < 0.5f))
                            Tex("_RampTexture");
                    }

                    var useFloor = Find("_UseFloor");
                    if (useFloor != null)
                    {
                        materialEditor.ShaderProperty(useFloor, useFloor.displayName);
                        using (new EditorGUI.DisabledScope(useFloor.floatValue < 0.5f))
                            Prop("_CelSteps");
                    }
                });
            });

            DrawBigGroup("음영 & 라이팅", () =>
            {
                DrawSection("1st Shadow", "_UseShadow1st", () =>
                {
                    Prop("_ShadowTint");
                    Prop("_ShadowStrength");
                    Prop("_ShadowThreshold");
                    Prop("_ShadowSmoothness");
                });

                DrawSection("2nd Shadow", "_UseShadow2nd", () =>
                {
                    Prop("_ShadowTint2");
                    Prop("_ShadowStrength2");
                    Prop("_Shadow2Threshold");
                    Prop("_Shadow2Smoothness");
                });

                DrawSection("Stylized SSS", "_UseSSS", () =>
                {
                    Prop("_SSSColor");
                    Prop("_SSSScale");
                    Prop("_SSSDistortion");
                    Prop("_GradientRange");
                    Prop("_GradientStrength");
                });

                DrawSection("Rim Light", "_UseRimLight", () =>
                {
                    Prop("_RimColor");
                    Prop("_RimPower");
                    Prop("_RimIntensity");
                });

                DrawSection("Rim Shade", "_UseRimShade", () =>
                {
                    Prop("_RimShadeColor");
                    Prop("_RimShadePower");
                    Prop("_RimShadeThreshold");
                    Prop("_RimShadeSmoothness");
                    Prop("_RimShadeIntensity");
                });
            });

            DrawBigGroup("표면 디테일", () =>
            {
                DrawSection("Normal Map", "_UseNormalMap", () =>
                {
                    Tex("_NormalMap");
                    Prop("_ShadowNormalStrength");
                });

                DrawSection("Specular", "_UseSpecular", () =>
                {
                    Prop("_SpecularSize");
                    Prop("_SpecularSmoothness");
                    Prop("_SpecularColor");
                    Prop("_SpecularIntensity");
                });

                DrawSection("MatCap", "_UseMatCap", () =>
                {
                    Tex("_MatCapTex");
                    Prop("_MatCapColor");
                    Prop("_MatCapIntensity");
                });
            });

            DrawBigGroup("Eye 전용", () =>
            {
                DrawSection("Parallax Mapping", "_UseParallax", () =>
                {
                    Tex("_ParallaxMap");
                    Prop("_Parallax");
                    Prop("_ParallaxClampUV");
                });

                DrawSection("See Through", "_UseSeeThrough", () =>
                {
                    Prop("_SeeThroughAlpha");
                });
            });

            DrawBigGroup("렌더링", () =>
            {
                DrawSection("Stencil", null, () =>
                {
                    Prop("_StencilRef");
                    Prop("_StencilReadMask");
                    Prop("_StencilWriteMask");
                    Prop("_StencilComp");
                    Prop("_StencilPass");
                    Prop("_StencilFail");
                    Prop("_StencilZFail");
                });
            });
        }
    }
}
