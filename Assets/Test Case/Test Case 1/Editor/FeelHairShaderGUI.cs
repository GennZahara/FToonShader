using UnityEditor;
using UnityEngine;

namespace FeelToon.ShaderInspector
{
    public class FeelHairShaderGUI : FeelShaderGUIBase
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
                DrawSection("MatCap", "_UseMatCap", () =>
                {
                    Tex("_MatCapTex");
                    Prop("_MatCapColor");
                    Prop("_MatCapIntensity");
                });

                DrawSection("Light Map", "_UseLightMap", () =>
                {
                    Tex("_LightMap");
                });
            });

            DrawBigGroup("Hair 전용", () =>
            {
                DrawSection("Hair Highlight", "_UseHairHighlight", () =>
                {
                    DrawSubHeader("옵션 토글");
                    Prop("_UseVirtualStrand");
                    Prop("_UseBitangent");
                    Prop("_UseKayToon");

                    var useKayToon = Find("_UseKayToon");
                    using (new EditorGUI.DisabledScope(useKayToon != null && useKayToon.floatValue < 0.5f))
                    {
                        Prop("_HairToonThreshold");
                        Prop("_HairToonSmoothness");
                    }

                    DrawSubHeader("Primary Band");
                    Prop("_HairSpecColor1");
                    Prop("_HairShift1");
                    Prop("_HairExp1");
                    Prop("_HairInt1");

                    DrawSubHeader("Secondary Band");
                    Prop("_HairSpecColor2");
                    Prop("_HairShift2");
                    Prop("_HairExp2");
                    Prop("_HairInt2");
                });
            });

            DrawBigGroup("렌더링 & 외곽", () =>
            {
                DrawSection("Outline", null, () =>
                {
                    Prop("_OutlineColor");
                    Prop("_OutlineWidth");
                });

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
