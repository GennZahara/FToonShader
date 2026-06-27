using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class FeelEyePanelController : FeelPanelControllerBase
{
    // Parallax
    Toggle useParallax;
    Slider parallaxStrength;

    // See Through
    Toggle useSeeThrough;
    Slider seeThroughAlpha;

    // MatCap
    Toggle useMatCap;
    Slider matCapIntensity;

    protected override IReadOnlyList<Material> TargetMaterials => Context.EyeMaterials;

    protected override void OnContextReady()
    {
        FindUIReferences();
        BindUIEvents();
        RefreshUI();
    }

    void FindUIReferences()
    {
        useParallax      = FindToggle("Use Parallax");
        parallaxStrength = FindSlider("Parallax Strength", 0f, 1f);

        useSeeThrough   = FindToggle("Use See Through");
        seeThroughAlpha = FindSlider("See Through Alpha", 0f, 1f);

        useMatCap       = FindToggle("Use MatCap");
        matCapIntensity = FindSlider("MatCap Intensity", 0f, 2f);
    }

    void BindUIEvents()
    {
        BindToggle(useParallax, "_UseParallax", "_USE_PARALLAX");
        BindSlider(parallaxStrength, "_Parallax");

        BindToggle(useSeeThrough, "_UseSeeThrough", "_USE_SEE_THROUGH");
        BindSlider(seeThroughAlpha, "_SeeThroughAlpha");

        BindToggle(useMatCap, "_UseMatCap", "_USE_MATCAP");
        BindSlider(matCapIntensity, "_MatCapIntensity");

        // ── Gating: 마스터 토글 OFF → 종속 컨트롤 비활성 ──
        BindGating(useParallax, parallaxStrength);
        BindGating(useSeeThrough, seeThroughAlpha);
        BindGating(useMatCap, matCapIntensity);
    }

    protected override void RefreshUIFromMaterials()
    {
        if (TargetMaterials.Count == 0) return;

        SuspendApply = true;
        try
        {
            SetToggleFromMaterial(useParallax,      "_UseParallax");
            SetSliderFromMaterial(parallaxStrength, "_Parallax");

            SetToggleFromMaterial(useSeeThrough,   "_UseSeeThrough");
            SetSliderFromMaterial(seeThroughAlpha, "_SeeThroughAlpha");

            SetToggleFromMaterial(useMatCap, "_UseMatCap");
            SetSliderFromMaterial(matCapIntensity, "_MatCapIntensity");
        }
        finally { SuspendApply = false; }
    }
}
