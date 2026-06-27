using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FeelFacePanelController : FeelPanelControllerBase
{
    // SDF (face-unique)
    Toggle useSdfFace;
    Toggle useSdfTex;
    Toggle useSdfDual;   // SDF 텍스처 모드에서 R/G 듀얼맵 on/off (off=B+미러)

    // 1st Shadow
    Toggle use1stShadow;
    Slider shadowStrength, shadowThreshold, shadowSoftness, shadowOffset;
    Slider shadowTintR, shadowTintG, shadowTintB;

    // 2nd Shadow
    Toggle use2ndShadow;
    Slider shadow2Strength, shadow2Threshold, shadow2Smoothness;
    Slider shadow2TintR, shadow2TintG, shadow2TintB;

    // SSS
    Toggle useSSS;
    Slider sssScale, sssDistortion, sssGradientRange, sssGradientStrength;
    Slider sssColorR, sssColorG, sssColorB;

    // Rim Light
    Toggle useRimLight;
    Slider rimPower, rimIntensity;
    Slider rimColorR, rimColorG, rimColorB;

    // Rim Shade
    Toggle useRimShade;
    Slider rimShadeIntensity, rimShadePower, rimShadeThreshold, rimShadeSmoothness;
    Slider rimShadeColorR, rimShadeColorG, rimShadeColorB;

    // Outline
    Slider outlineWidth, outlineColorR, outlineColorG, outlineColorB;

    // MatCap
    Toggle useMatCap;
    Slider matCapIntensity;

    protected override IReadOnlyList<Material> TargetMaterials => Context.FaceMaterials;

    protected override void OnContextReady()
    {
        FindUIReferences();
        BindUIEvents();
        RefreshUI();
    }

    void FindUIReferences()
    {
        useSdfFace   = FindToggle("Use SDF Face Shadow");
        useSdfTex    = FindToggle("Use SDF Texture");
        useSdfDual   = FindToggle("Use SDF Dual");

        use1stShadow     = FindToggle("Use 1st Shadow");
        shadowStrength   = FindSlider("Shadow Strength", 0f, 1f);
        shadowThreshold  = FindSlider("Shadow Threshold", 0f, 1f);
        shadowSoftness   = FindSlider("Shadow Softness", 0.01f, 0.5f);
        shadowOffset     = FindSlider("Shadow Offset", -0.5f, 0.5f);
        FindColorSliders("Shadow Tint", out shadowTintR, out shadowTintG, out shadowTintB);

        use2ndShadow      = FindToggle("Use 2nd Shadow");
        shadow2Strength   = FindSlider("2nd Shadow Strength", 0f, 1f);
        shadow2Threshold  = FindSlider("2nd Shadow Threshold", 0f, 1f);
        shadow2Smoothness = FindSlider("2nd Shadow Smoothness", 0f, 0.5f);
        FindColorSliders("2nd Shadow Tint", out shadow2TintR, out shadow2TintG, out shadow2TintB);

        useSSS              = FindToggle("Use SSS");
        sssScale            = FindSlider("SSS Scale", 0f, 2f);
        sssDistortion       = FindSlider("SSS Distortion", -1f, 1f);
        sssGradientRange    = FindSlider("SSS Gradient Range", 0.01f, 1f);
        sssGradientStrength = FindSlider("SSS Gradient Strength", 0f, 1f);
        FindColorSliders("SSS Color", out sssColorR, out sssColorG, out sssColorB);

        useRimLight  = FindToggle("Use Rim Light");
        rimPower     = FindSlider("Rim Power", 1f, 10f);
        rimIntensity = FindSlider("Rim Intensity", 0f, 2f);
        FindColorSliders("Rim Color", out rimColorR, out rimColorG, out rimColorB);

        useRimShade        = FindToggle("Use Rim Shade");
        rimShadeIntensity  = FindSlider("Rim Shade Intensity", 0f, 1f);
        rimShadePower      = FindSlider("Rim Shade Power", 0.1f, 10f);
        rimShadeThreshold  = FindSlider("Rim Shade Threshold", 0f, 1f);
        rimShadeSmoothness = FindSlider("Rim Shade Smoothness", 0f, 0.5f);
        FindColorSliders("Rim Shade Color", out rimShadeColorR, out rimShadeColorG, out rimShadeColorB);

        outlineWidth  = FindSlider("Outline Width", 0f, 3f);
        outlineColorR = FindSlider("Outline Color R", 0f, 1f);
        outlineColorG = FindSlider("Outline Color G", 0f, 1f);
        outlineColorB = FindSlider("Outline Color B", 0f, 1f);

        useMatCap       = FindToggle("Use MatCap");
        matCapIntensity = FindSlider("MatCap Intensity", 0f, 2f);
    }

    void BindUIEvents()
    {
        BindToggle(useSdfFace, "_UseSdfFace", "_USE_SDF_FACE");
        BindToggle(useSdfTex,  "_UseSdfTex",  "_USE_SDF_TEX");
        BindToggle(useSdfDual, "_UseSdfDual", "");   // uniform float, 키워드 없음

        BindToggle(use1stShadow, "_UseShadow1st", "_USE_SHADOW_1ST");
        BindSlider(shadowStrength,  "_ShadowStrength");
        BindSlider(shadowThreshold, "_ShadowThreshold");
        BindSlider(shadowSoftness,  "_ShadowSoftness");
        BindSlider(shadowOffset,    "_ShadowOffset");
        BindColorRGB(shadowTintR, shadowTintG, shadowTintB, "_ShadowTint");

        BindToggle(use2ndShadow, "_UseShadow2nd", "_USE_SHADOW_2ND");
        BindSlider(shadow2Strength,   "_ShadowStrength2");
        BindSlider(shadow2Threshold,  "_Shadow2Threshold");
        BindSlider(shadow2Smoothness, "_Shadow2Smoothness");
        BindColorRGB(shadow2TintR, shadow2TintG, shadow2TintB, "_ShadowTint2");

        BindToggle(useSSS, "_UseSSS", "_USE_SSS");
        BindSlider(sssScale,            "_SSSScale");
        BindSlider(sssDistortion,       "_SSSDistortion");
        BindSlider(sssGradientRange,    "_GradientRange");
        BindSlider(sssGradientStrength, "_GradientStrength");
        BindColorRGB(sssColorR, sssColorG, sssColorB, "_SSSColor");

        BindToggle(useRimLight, "_UseRimLight", "_USE_RIM_LIGHT");
        BindSlider(rimPower,     "_RimPower");
        BindSlider(rimIntensity, "_RimIntensity");
        BindColorRGB(rimColorR, rimColorG, rimColorB, "_RimColor");

        BindToggle(useRimShade, "_UseRimShade", "_USE_RIM_SHADE");
        BindSlider(rimShadeIntensity,  "_RimShadeIntensity");
        BindSlider(rimShadePower,      "_RimShadePower");
        BindSlider(rimShadeThreshold,  "_RimShadeThreshold");
        BindSlider(rimShadeSmoothness, "_RimShadeSmoothness");
        BindColorRGB(rimShadeColorR, rimShadeColorG, rimShadeColorB, "_RimShadeColor");

        BindSlider(outlineWidth, "_OutlineWidth");
        BindColorChannel(outlineColorR, "_OutlineColor", 0);
        BindColorChannel(outlineColorG, "_OutlineColor", 1);
        BindColorChannel(outlineColorB, "_OutlineColor", 2);

        BindToggle(useMatCap, "_UseMatCap", "_USE_MATCAP");
        BindSlider(matCapIntensity, "_MatCapIntensity");

        // ── Gating: 마스터 토글 OFF → 종속 컨트롤 비활성 ──
        // (Shadow Threshold/Softness/Offset은 SDF·셀쉐이딩 공용 파라미터라 게이팅 제외)
        BindGating(useSdfFace, useSdfTex);
        BindGating(useSdfTex,  useSdfDual);   // 듀얼맵은 SDF 텍스처 모드일 때만 의미 있음
        BindGating(use1stShadow, shadowStrength, shadowTintR, shadowTintG, shadowTintB);
        BindGating(use2ndShadow, shadow2Strength, shadow2Threshold, shadow2Smoothness,
                   shadow2TintR, shadow2TintG, shadow2TintB);
        BindGating(useSSS, sssScale, sssDistortion, sssGradientRange, sssGradientStrength,
                   sssColorR, sssColorG, sssColorB);
        BindGating(useRimLight, rimPower, rimIntensity, rimColorR, rimColorG, rimColorB);
        BindGating(useRimShade, rimShadeIntensity, rimShadePower, rimShadeThreshold,
                   rimShadeSmoothness, rimShadeColorR, rimShadeColorG, rimShadeColorB);
        BindGating(useMatCap, matCapIntensity);
    }

    protected override void RefreshUIFromMaterials()
    {
        if (TargetMaterials.Count == 0) return;

        SuspendApply = true;
        try
        {
            SetToggleFromMaterial(useSdfFace,   "_UseSdfFace");
            SetToggleFromMaterial(useSdfTex,    "_UseSdfTex");
            SetToggleFromMaterial(useSdfDual,   "_UseSdfDual");

            SetToggleFromMaterial(use1stShadow,    "_UseShadow1st");
            SetSliderFromMaterial(shadowStrength,  "_ShadowStrength");
            SetSliderFromMaterial(shadowThreshold, "_ShadowThreshold");
            SetSliderFromMaterial(shadowSoftness,  "_ShadowSoftness");
            SetSliderFromMaterial(shadowOffset,    "_ShadowOffset");
            SetSlidersFromColorRGB(shadowTintR, shadowTintG, shadowTintB, "_ShadowTint");

            SetToggleFromMaterial(use2ndShadow,     "_UseShadow2nd");
            SetSliderFromMaterial(shadow2Strength,   "_ShadowStrength2");
            SetSliderFromMaterial(shadow2Threshold,  "_Shadow2Threshold");
            SetSliderFromMaterial(shadow2Smoothness, "_Shadow2Smoothness");
            SetSlidersFromColorRGB(shadow2TintR, shadow2TintG, shadow2TintB, "_ShadowTint2");

            SetToggleFromMaterial(useSSS,   "_UseSSS");
            SetSliderFromMaterial(sssScale,            "_SSSScale");
            SetSliderFromMaterial(sssDistortion,       "_SSSDistortion");
            SetSliderFromMaterial(sssGradientRange,    "_GradientRange");
            SetSliderFromMaterial(sssGradientStrength, "_GradientStrength");
            SetSlidersFromColorRGB(sssColorR, sssColorG, sssColorB, "_SSSColor");

            SetToggleFromMaterial(useRimLight,  "_UseRimLight");
            SetSliderFromMaterial(rimPower,     "_RimPower");
            SetSliderFromMaterial(rimIntensity, "_RimIntensity");
            SetSlidersFromColorRGB(rimColorR, rimColorG, rimColorB, "_RimColor");

            SetToggleFromMaterial(useRimShade,       "_UseRimShade");
            SetSliderFromMaterial(rimShadeIntensity,  "_RimShadeIntensity");
            SetSliderFromMaterial(rimShadePower,      "_RimShadePower");
            SetSliderFromMaterial(rimShadeThreshold,  "_RimShadeThreshold");
            SetSliderFromMaterial(rimShadeSmoothness, "_RimShadeSmoothness");
            SetSlidersFromColorRGB(rimShadeColorR, rimShadeColorG, rimShadeColorB, "_RimShadeColor");

            SetSliderFromMaterial(outlineWidth, "_OutlineWidth");
            SetSliderFromColorChannel(outlineColorR, "_OutlineColor", 0);
            SetSliderFromColorChannel(outlineColorG, "_OutlineColor", 1);
            SetSliderFromColorChannel(outlineColorB, "_OutlineColor", 2);

            SetToggleFromMaterial(useMatCap, "_UseMatCap");
            SetSliderFromMaterial(matCapIntensity, "_MatCapIntensity");
        }
        finally { SuspendApply = false; }
    }
}
