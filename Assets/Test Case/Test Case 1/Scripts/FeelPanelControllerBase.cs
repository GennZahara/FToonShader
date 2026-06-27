using System.Collections.Generic;
using TMPro;
using UnityEngine;
using UnityEngine.UI;

public abstract class FeelPanelControllerBase : MonoBehaviour
{
    protected FeelPanelContext Context { get; private set; }
    protected bool SuspendApply { get; set; }
    bool initialized;

    // 슬라이더 → 값 표시 라벨 캐시 (행의 "Value" 자식, 없으면 null 캐시)
    readonly Dictionary<Slider, TMP_Text> valueLabels = new Dictionary<Slider, TMP_Text>();

    // 토글 → 종속 컨트롤 게이팅 그룹 (RefreshUI 후 일괄 적용)
    readonly List<(Toggle master, Selectable[] dependents)> gatingGroups
        = new List<(Toggle, Selectable[])>();

    protected abstract IReadOnlyList<Material> TargetMaterials { get; }

    protected virtual void OnEnable()
    {
        if (initialized) return;
        Context = GetComponentInParent<FeelPanelContext>(true);
        if (Context == null) Context = FindObjectOfType<FeelPanelContext>(true);
        if (Context == null)
        {
            Debug.LogError($"{GetType().Name}: FeelPanelContext not found in hierarchy.");
            return;
        }
        initialized = true;
        OnContextReady();
    }

    protected abstract void OnContextReady();

    // ===== UI refresh entry point (Reset 버튼 등 외부 호출용) =====

    public void RefreshUI()
    {
        if (!initialized) return;
        RefreshUIFromMaterials();
        ApplyAllGating();
    }

    protected abstract void RefreshUIFromMaterials();

    // ===== Gating (마스터 토글 OFF → 종속 컨트롤 비활성) =====

    protected void BindGating(Toggle master, params Selectable[] dependents)
    {
        if (master == null) return;
        gatingGroups.Add((master, dependents));
        // 어떤 마스터가 바뀌든 전체를 다시 평가 — 중첩 게이팅(부모→자식 마스터)이 한 번에 전파되도록.
        master.onValueChanged.AddListener(_ => ApplyAllGating());
    }

    // 등록 순서(부모 먼저 → 자식)대로 평가하므로 부모가 비활성이면 자식 마스터도 비활성으로 전파됨.
    // 종속 컨트롤은 "마스터가 켜져 있고(isOn) + 마스터 자신도 활성(interactable)"일 때만 활성.
    protected void ApplyAllGating()
    {
        foreach (var (master, dependents) in gatingGroups)
            SetInteractable(dependents, master.isOn && master.interactable);
        OnAfterGating();
    }

    // 단순 마스터-종속 규칙으로 표현 안 되는 복합 게이팅을 파생 클래스가 후처리하는 훅.
    protected virtual void OnAfterGating() { }

    static void SetInteractable(Selectable[] targets, bool on)
    {
        if (targets == null) return;
        for (int i = 0; i < targets.Length; i++)
            if (targets[i] != null) targets[i].interactable = on;
    }

    // ===== Value label (슬라이더 행의 "Value" TMP 텍스트 자동 갱신) =====

    protected void UpdateValueLabel(Slider s)
    {
        if (s == null) return;

        if (!valueLabels.TryGetValue(s, out var label))
        {
            var parent = s.transform.parent;
            var tr = parent != null ? parent.Find("Value") : null;
            label = tr != null ? tr.GetComponent<TMP_Text>() : null;
            valueLabels[s] = label;   // 못 찾아도 null 캐시 — 매 프레임 Find 방지
        }

        if (label != null)
            label.text = s.wholeNumbers ? s.value.ToString("0") : s.value.ToString("0.00");
    }

    // ===== Apply helpers (UI -> materials) =====

    protected static void ApplyFloat(IReadOnlyList<Material> mats, string prop, float value)
    {
        if (mats == null) return;
        for (int i = 0; i < mats.Count; i++)
        {
            var m = mats[i];
            if (m != null && m.HasProperty(prop)) m.SetFloat(prop, value);
        }
    }

    protected static void ApplyColor(IReadOnlyList<Material> mats, string prop, Color value)
    {
        if (mats == null) return;
        for (int i = 0; i < mats.Count; i++)
        {
            var m = mats[i];
            if (m != null && m.HasProperty(prop)) m.SetColor(prop, value);
        }
    }

    protected static void ApplyToggleKeyword(IReadOnlyList<Material> mats, string floatProp, string keyword, bool enabled)
    {
        if (mats == null) return;
        for (int i = 0; i < mats.Count; i++)
        {
            var m = mats[i];
            if (m == null) continue;
            if (!string.IsNullOrEmpty(floatProp) && m.HasProperty(floatProp))
                m.SetFloat(floatProp, enabled ? 1f : 0f);
            if (!string.IsNullOrEmpty(keyword))
            {
                if (enabled) m.EnableKeyword(keyword);
                else m.DisableKeyword(keyword);
            }
        }
    }

    // ===== Read helpers (materials[0] -> UI) =====

    protected static float ReadFloat(IReadOnlyList<Material> mats, string prop, float fallback)
    {
        if (mats == null || mats.Count == 0) return fallback;
        var m = mats[0];
        if (m == null || !m.HasProperty(prop)) return fallback;
        return m.GetFloat(prop);
    }

    protected static Color ReadColor(IReadOnlyList<Material> mats, string prop, Color fallback)
    {
        if (mats == null || mats.Count == 0) return fallback;
        var m = mats[0];
        if (m == null || !m.HasProperty(prop)) return fallback;
        return m.GetColor(prop);
    }

    protected static bool ReadToggle(IReadOnlyList<Material> mats, string floatProp, bool fallback)
    {
        if (mats == null || mats.Count == 0) return fallback;
        var m = mats[0];
        if (m == null || !m.HasProperty(floatProp)) return fallback;
        return m.GetFloat(floatProp) > 0.5f;
    }

    // ===== Binding helpers (UI event -> material apply, gated by SuspendApply) =====

    protected void BindToggle(Toggle t, string floatProp, string keyword)
    {
        if (t == null) return;
        WarnMissingProperty(floatProp);
        t.onValueChanged.AddListener(isOn =>
        {
            if (SuspendApply) return;
            ApplyToggleKeyword(TargetMaterials, floatProp, keyword, isOn);
        });
    }

    protected void BindSlider(Slider s, string floatProp)
    {
        if (s == null) return;
        WarnMissingProperty(floatProp);
        UpdateValueLabel(s);
        s.onValueChanged.AddListener(v =>
        {
            UpdateValueLabel(s);   // 라벨은 SuspendApply와 무관하게 항상 갱신
            if (SuspendApply) return;
            ApplyFloat(TargetMaterials, floatProp, v);
        });
    }

    protected void BindColorChannel(Slider s, string colorProp, int channel)
    {
        if (s == null) return;
        WarnMissingProperty(colorProp);   // RGB로 3회 호출돼도 warnedProps가 1회만 경고
        UpdateValueLabel(s);
        s.onValueChanged.AddListener(v =>
        {
            UpdateValueLabel(s);
            if (SuspendApply) return;
            var c = ReadColor(TargetMaterials, colorProp, Color.black);
            if (channel == 0) c.r = v;
            else if (channel == 1) c.g = v;
            else if (channel == 2) c.b = v;
            c.a = 1f;   // 이 패널의 색상 프로퍼티는 RGB만 사용 — 알파 채널은 항상 1로 고정.
                        // 알파를 쓰는 프로퍼티가 추가되면 이 줄이 알파를 덮어쓰니 주의.
            ApplyColor(TargetMaterials, colorProp, c);
        });
    }

    // R/G/B 3개 슬라이더를 한 색상 프로퍼티에 일괄 바인딩
    protected void BindColorRGB(Slider r, Slider g, Slider b, string colorProp)
    {
        BindColorChannel(r, colorProp, 0);
        BindColorChannel(g, colorProp, 1);
        BindColorChannel(b, colorProp, 2);
    }

    // ===== Refresh helpers (material -> UI, no-notify) =====

    protected void SetToggleFromMaterial(Toggle t, string floatProp)
    {
        if (t == null) return;
        t.SetIsOnWithoutNotify(ReadToggle(TargetMaterials, floatProp, t.isOn));
    }

    protected void SetSliderFromMaterial(Slider s, string floatProp)
    {
        if (s == null) return;
        s.SetValueWithoutNotify(ReadFloat(TargetMaterials, floatProp, s.value));
        UpdateValueLabel(s);   // SetValueWithoutNotify는 이벤트 미발생 — 라벨 수동 갱신
    }

    protected void SetSliderFromColorChannel(Slider s, string colorProp, int channel)
    {
        if (s == null) return;
        var c = ReadColor(TargetMaterials, colorProp, Color.white);
        float v = channel == 0 ? c.r : (channel == 1 ? c.g : c.b);
        s.SetValueWithoutNotify(v);
        UpdateValueLabel(s);
    }

    protected void SetSlidersFromColorRGB(Slider r, Slider g, Slider b, string colorProp)
    {
        SetSliderFromColorChannel(r, colorProp, 0);
        SetSliderFromColorChannel(g, colorProp, 1);
        SetSliderFromColorChannel(b, colorProp, 2);
    }

    // ===== UI lookup =====

    // 기대한 컨트롤/프로퍼티를 못 찾으면 경고 — 행 이름 오타나 셰이더 프로퍼티 오타로
    // 바인딩이 조용히 죽는 것을 방지. (선택적 컨트롤이 많은 파생은 false로 오버라이드)
    protected virtual bool LogMissingBindings => true;

    readonly HashSet<string> warnedProps = new HashSet<string>();

    void WarnMissing(string kind, string name)
    {
        if (LogMissingBindings)
            Debug.LogWarning($"{GetType().Name}: {kind} '{name}' 을(를) '{this.name}' 하위에서 찾지 못했습니다. 씬의 UI 행 이름을 확인하세요.", this);
    }

    // 바인딩하려는 셰이더 프로퍼티가 타깃 머티리얼에 실제로 존재하는지 검증.
    // 머티리얼이 아직 없으면(Count==0) 검증 불가로 스킵. 같은 프로퍼티는 1회만 경고.
    // (HasProperty 가드가 오타를 조용히 삼키는 것을 보완 — 슬라이더는 움직이는데 셰이더 무반응 방지)
    void WarnMissingProperty(string prop)
    {
        if (!LogMissingBindings || string.IsNullOrEmpty(prop)) return;
        var mats = TargetMaterials;
        if (mats == null || mats.Count == 0) return;
        for (int i = 0; i < mats.Count; i++)
            if (mats[i] != null && mats[i].HasProperty(prop)) return;   // 하나라도 있으면 정상
        if (warnedProps.Add(prop))
            Debug.LogWarning($"{GetType().Name}: 프로퍼티 '{prop}' 이(가) 타깃 머티리얼에 없습니다. 셰이더 프로퍼티 이름을 확인하세요.", this);
    }

    protected Toggle FindToggle(string name)
    {
        var tr = transform.Find(name);
        var t = tr != null ? tr.GetComponent<Toggle>() : null;
        if (t == null) WarnMissing("Toggle", name);
        return t;
    }

    protected Slider FindSlider(string rowName)
    {
        var tr = transform.Find(rowName + "/Slider");
        var s = tr != null ? tr.GetComponent<Slider>() : null;
        if (s == null) WarnMissing("Slider", rowName + "/Slider");
        return s;
    }

    // 범위 지정 버전 — 씬에서 슬라이더 범위를 따로 설정할 필요 없도록.
    // Bind 전(리스너 없음)에 호출되므로 클램프로 인한 이벤트 발생 없음.
    protected Slider FindSlider(string rowName, float min, float max)
    {
        var s = FindSlider(rowName);
        if (s != null)
        {
            s.minValue = min;
            s.maxValue = max;
        }
        return s;
    }

    // "이름 R/G/B" 3행을 찾아 0~1 범위로 설정
    protected void FindColorSliders(string baseName, out Slider r, out Slider g, out Slider b)
    {
        r = FindSlider(baseName + " R", 0f, 1f);
        g = FindSlider(baseName + " G", 0f, 1f);
        b = FindSlider(baseName + " B", 0f, 1f);
    }
}
