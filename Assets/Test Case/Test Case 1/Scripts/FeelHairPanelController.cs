using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FeelHairPanelController : FeelPanelControllerBase
{
    // Ramp / Cel
    Toggle useRampTex, useFloor;
    Slider celSteps;

    // Hair Highlight (Toon)
    Toggle useKayToon;
    Slider toonThreshold, toonSmoothness;

    // Kajiya-Kay 탄젠트 방향 모드 (셰이더 우선순위: Virtual Strand > Bitangent > Tangent)
    Toggle useVirtualStrand, useBitangent;

    // 1st Shadow
    Toggle use1stShadow;
    Slider shadowStrength, shadowThreshold, shadowSmoothness;
    Slider shadowTintR, shadowTintG, shadowTintB;

    // 2nd Shadow
    Toggle use2ndShadow;
    Slider shadow2Strength, shadow2Threshold, shadow2Smoothness;
    Slider shadow2TintR, shadow2TintG, shadow2TintB;

    // SSS
    Toggle useSSS;
    Slider sssScale, sssDistortion, sssGradientRange, sssGradientStrength;
    Slider sssColorR, sssColorG, sssColorB;

    // Hair Spec (Highlight master)
    Toggle useHairSpec;
    Slider primaryShift, primaryExponent, primaryIntensity;
    Slider secondaryShift, secondaryExponent, secondaryIntensity;
    Slider primarySpecColorR, primarySpecColorG, primarySpecColorB;
    Slider secondarySpecColorR, secondarySpecColorG, secondarySpecColorB;

    // MatCap / Light Map
    Toggle useMatCap, useLightMap;
    Slider matCapIntensity;

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

    protected override IReadOnlyList<Material> TargetMaterials => Context.HairMaterials;

    protected override void OnContextReady()
    {
        FindUIReferences();
        BindUIEvents();
        RefreshUI();
    }

    void FindUIReferences()
    {
        useRampTex = FindToggle("Use Ramp Texture");
        useFloor   = FindToggle("Use Floor Quantization");
        celSteps   = FindSlider("Cel Steps", 2f, 8f);

        useKayToon     = FindToggle("Use Kay Toon");
        toonThreshold  = FindSlider("Toon Threshold", 0f, 1f);
        toonSmoothness = FindSlider("Toon Smoothness", 0f, 0.5f);

        useVirtualStrand = FindToggle("Use Virtual Strand");
        useBitangent     = FindToggle("Use Bitangent");

        use1stShadow     = FindToggle("Use 1st Shadow");
        shadowStrength   = FindSlider("Shadow Strength", 0f, 1f);
        shadowThreshold  = FindSlider("Shadow Threshold", 0f, 1f);
        shadowSmoothness = FindSlider("Shadow Smoothness", 0f, 0.5f);
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

        useHairSpec       = FindToggle("Use Hair Spec");
        primaryShift      = FindSlider("Primary Shift", -1f, 1f);
        primaryExponent   = FindSlider("Primary Exponent", 1f, 200f);
        primaryIntensity  = FindSlider("Primary Intensity", 0f, 2f);
        secondaryShift    = FindSlider("Secondary Shift", -1f, 1f);
        secondaryExponent = FindSlider("Secondary Exponent", 1f, 200f);
        secondaryIntensity = FindSlider("Secondary Intensity", 0f, 1f);
        FindColorSliders("Primary Spec Color",
                         out primarySpecColorR, out primarySpecColorG, out primarySpecColorB);
        FindColorSliders("Secondary Spec Color",
                         out secondarySpecColorR, out secondarySpecColorG, out secondarySpecColorB);

        useMatCap       = FindToggle("Use MatCap");
        matCapIntensity = FindSlider("MatCap Intensity", 0f, 2f);
        useLightMap     = FindToggle("Use Light Map");

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
    }

    void BindUIEvents()
    {
        BindToggle(useRampTex, "_UseRampTex", "_USE_RAMP_TEX");
        BindToggle(useFloor,   "_UseFloor",   "_USE_FLOOR");
        BindSlider(celSteps,   "_CelSteps");

        BindToggle(useKayToon, "_UseKayToon", "_USE_KAY_TOON");
        BindSlider(toonThreshold,  "_HairToonThreshold");
        BindSlider(toonSmoothness, "_HairToonSmoothness");

        BindToggle(useVirtualStrand, "_UseVirtualStrand", "_USE_VIRTUAL_STRAND");
        BindToggle(useBitangent,     "_UseBitangent",     "_USE_BITANGENT");

        // Virtual Strand가 바뀌면 전체 게이팅 재평가 — Bitangent 활성 조건이 OnAfterGating에서 갱신됨
        if (useVirtualStrand != null) useVirtualStrand.onValueChanged.AddListener(_ => ApplyAllGating());

        BindToggle(use1stShadow, "_UseShadow1st", "_USE_SHADOW_1ST");
        BindSlider(shadowStrength,   "_ShadowStrength");
        BindSlider(shadowThreshold,  "_ShadowThreshold");
        BindSlider(shadowSmoothness, "_ShadowSmoothness");
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

        BindToggle(useHairSpec, "_UseHairHighlight", "_USE_HAIR_HIGHLIGHT");
        BindSlider(primaryShift,      "_HairShift1");
        BindSlider(primaryExponent,   "_HairExp1");
        BindSlider(primaryIntensity,  "_HairInt1");
        BindSlider(secondaryShift,    "_HairShift2");
        BindSlider(secondaryExponent, "_HairExp2");
        BindSlider(secondaryIntensity, "_HairInt2");
        BindColorRGB(primarySpecColorR, primarySpecColorG, primarySpecColorB, "_HairSpecColor1");
        BindColorRGB(secondarySpecColorR, secondarySpecColorG, secondarySpecColorB, "_HairSpecColor2");

        BindToggle(useMatCap,   "_UseMatCap",   "_USE_MATCAP");
        BindSlider(matCapIntensity, "_MatCapIntensity");
        BindToggle(useLightMap, "_UseLightMap", "_USE_LIGHT_MAP");

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

        // ── Gating: 마스터 토글 OFF → 종속 컨트롤 비활성 ──
        BindGating(useRampTex, useFloor);
        BindGating(useFloor, celSteps);

        // Hair Highlight(Kajiya-Kay)가 OFF면 탄젠트 모드·Kay Toon·스펙 컬러까지 전부 무의미하므로 함께 게이팅.
        // useHairSpec → useKayToon → toon* 의 2단 중첩이라 useHairSpec 그룹을 useKayToon 그룹보다 먼저 등록해야
        // ApplyAllGating 한 패스에서 캐스케이드가 올바르게 전파됨.
        // (useBitangent는 "하이라이트 ON + Virtual Strand OFF" 복합 조건이라 OnAfterGating에서 처리)
        BindGating(useHairSpec, primaryShift, primaryExponent, primaryIntensity,
                   secondaryShift, secondaryExponent, secondaryIntensity,
                   primarySpecColorR, primarySpecColorG, primarySpecColorB,
                   secondarySpecColorR, secondarySpecColorG, secondarySpecColorB,
                   useKayToon, useVirtualStrand);
        BindGating(useKayToon, toonThreshold, toonSmoothness);

        BindGating(use1stShadow, shadowStrength, shadowThreshold, shadowSmoothness,
                   shadowTintR, shadowTintG, shadowTintB);
        BindGating(use2ndShadow, shadow2Strength, shadow2Threshold, shadow2Smoothness,
                   shadow2TintR, shadow2TintG, shadow2TintB);
        BindGating(useSSS, sssScale, sssDistortion, sssGradientRange, sssGradientStrength,
                   sssColorR, sssColorG, sssColorB);
        BindGating(useRimLight, rimPower, rimIntensity, rimColorR, rimColorG, rimColorB);
        BindGating(useRimShade, rimShadeIntensity, rimShadePower, rimShadeThreshold,
                   rimShadeSmoothness, rimShadeColorR, rimShadeColorG, rimShadeColorB);
        BindGating(useMatCap, matCapIntensity);
    }

    // useBitangent는 하이라이트가 켜져 있고(useHairSpec) Virtual Strand가 꺼져 있을 때만 활성.
    // (셰이더 우선순위: Virtual Strand > Bitangent > Tangent — VS가 켜지면 Bitangent는 무시됨)
    protected override void OnAfterGating()
    {
        if (useBitangent != null)
            useBitangent.interactable =
                useHairSpec != null && useHairSpec.isOn && useHairSpec.interactable
                && (useVirtualStrand == null || !useVirtualStrand.isOn);
    }

    protected override void RefreshUIFromMaterials()
    {
        if (TargetMaterials.Count == 0) return;

        SuspendApply = true;
        try
        {
            SetToggleFromMaterial(useRampTex, "_UseRampTex");
            SetToggleFromMaterial(useFloor,   "_UseFloor");
            SetSliderFromMaterial(celSteps,   "_CelSteps");

            SetToggleFromMaterial(useKayToon,     "_UseKayToon");
            SetSliderFromMaterial(toonThreshold,  "_HairToonThreshold");
            SetSliderFromMaterial(toonSmoothness, "_HairToonSmoothness");

            SetToggleFromMaterial(useVirtualStrand, "_UseVirtualStrand");
            SetToggleFromMaterial(useBitangent,     "_UseBitangent");

            SetToggleFromMaterial(use1stShadow,     "_UseShadow1st");
            SetSliderFromMaterial(shadowStrength,   "_ShadowStrength");
            SetSliderFromMaterial(shadowThreshold,  "_ShadowThreshold");
            SetSliderFromMaterial(shadowSmoothness, "_ShadowSmoothness");
            SetSlidersFromColorRGB(shadowTintR, shadowTintG, shadowTintB, "_ShadowTint");

            SetToggleFromMaterial(use2ndShadow,      "_UseShadow2nd");
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

            SetToggleFromMaterial(useHairSpec,        "_UseHairHighlight");
            SetSliderFromMaterial(primaryShift,       "_HairShift1");
            SetSliderFromMaterial(primaryExponent,    "_HairExp1");
            SetSliderFromMaterial(primaryIntensity,   "_HairInt1");
            SetSliderFromMaterial(secondaryShift,     "_HairShift2");
            SetSliderFromMaterial(secondaryExponent,  "_HairExp2");
            SetSliderFromMaterial(secondaryIntensity, "_HairInt2");
            SetSlidersFromColorRGB(primarySpecColorR, primarySpecColorG, primarySpecColorB,
                                   "_HairSpecColor1");
            SetSlidersFromColorRGB(secondarySpecColorR, secondarySpecColorG, secondarySpecColorB,
                                   "_HairSpecColor2");

            SetToggleFromMaterial(useMatCap,   "_UseMatCap");
            SetSliderFromMaterial(matCapIntensity, "_MatCapIntensity");
            SetToggleFromMaterial(useLightMap, "_UseLightMap");

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
        }
        finally { SuspendApply = false; }
        // 게이팅(탄젠트 모드 포함)은 base.RefreshUI가 RefreshUIFromMaterials 직후 ApplyAllGating→OnAfterGating로 처리
    }
}
