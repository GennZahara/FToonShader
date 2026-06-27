using UnityEditor;
using UnityEngine;

namespace FeelToon.ShaderInspector
{
    public class FeelFaceShaderGUI : FeelShaderGUIBase
    {
        protected override void DrawSections()
        {
            DrawBigGroup("기본", () =>
            {
                Prop("_BaseColor");
                Tex("_MainTex");
            });

            DrawBigGroup("Face 전용", () =>
            {
                DrawSection("Face Shadow", "_UseSdfFace", () =>
                {
                    DrawSubHeader("SDF 옵션");
                    var useSdf = Find("_UseSdfFace");
                    var useSdfTex = Find("_UseSdfTex");

                    using (new EditorGUI.DisabledScope(useSdf != null && useSdf.floatValue < 0.5f))
                    {
                        Prop("_UseSdfTex");
                        using (new EditorGUI.DisabledScope(useSdfTex != null && useSdfTex.floatValue < 0.5f))
                        {
                            Tex("_SDFTexture");
                        }
                    }

                    DrawSubHeader("공통 셰이딩 파라미터");
                    Prop("_ShadowThreshold");
                    Prop("_ShadowSoftness");
                    Prop("_ShadowOffset");
                });
            });

            DrawBigGroup("음영 & 라이팅", () =>
            {
                DrawSection("1st Shadow", "_UseShadow1st", () =>
                {
                    Prop("_ShadowTint");
                    Prop("_ShadowStrength");
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
