using UnityEngine;
using UnityEngine.UI;

public class LightPanelController : MonoBehaviour
{
    [SerializeField] Light directionalLight;

    [SerializeField] GameObject directionalControlsGroup;
    [SerializeField] GameObject directionalDisabledMessage;

    [SerializeField] Transform multipleLightsParent;
    [SerializeField] Light[]   multipleLights;

    [SerializeField] GameObject multiControlsGroup;
    [SerializeField] GameObject multiDisabledMessage;

    const float RotateSpeed = 60f;   // °/s

    Toggle directionalToggle;
    Slider ambientSlider;
    Slider shadowStrengthSlider;
    Slider dirIntensitySlider;
    Slider rotXSlider;
    Slider rotYSlider;
    Toggle multipleLightsToggle;
    Slider multiRangeSlider;
    Slider multiIntensitySlider;
    Toggle rotateMultipleToggle;

    float rotX, rotY;

    void Awake()
    {
        if (directionalLight == null)
        {
            var go = GameObject.Find("Lighting Mode/Directional Light");
            if (go != null) directionalLight = go.GetComponent<Light>();
        }

        directionalToggle    = FindToggle("Directional Light");
        ambientSlider        = FindSlider("Ambient Light Intensity");
        shadowStrengthSlider = FindSlider("Light Shadow Strength");
        dirIntensitySlider   = FindSlider("Directional Light Intensity");
        rotXSlider           = FindSlider("Rotate Directional Light X");
        rotYSlider           = FindSlider("Rotate Directional Light Y");
        multipleLightsToggle = FindToggle("Multiple Lights");
        multiRangeSlider     = FindSlider("Multiple Pointlight Range");
        multiIntensitySlider = FindSlider("Multiple Pointlight Intensity");
        rotateMultipleToggle = FindToggle("Rotate Multiple Lights");

        InitSlider(ambientSlider,        0f, 3f, RenderSettings.ambientIntensity);
        InitSlider(shadowStrengthSlider, 0f, 1f, directionalLight != null ? directionalLight.shadowStrength : 1f);
        InitSlider(dirIntensitySlider,   0f, 3f, directionalLight != null ? directionalLight.intensity      : 1f);

        if (directionalLight != null)
        {
            var e = directionalLight.transform.eulerAngles;
            rotX = NormalizeAngle(e.x);
            rotY = NormalizeAngle(e.y);
            if (directionalToggle != null) directionalToggle.isOn = directionalLight.gameObject.activeSelf;
        }
        InitSlider(rotXSlider, -90f, 90f, rotX);
        InitSlider(rotYSlider, -180f, 180f, rotY);

        // Multiple Lights 초기값 — 첫 광원 기준 (배열이 비어있으면 기본값)
        float initRange     = (multipleLights != null && multipleLights.Length > 0 && multipleLights[0] != null) ? multipleLights[0].range     : 10f;
        float initIntensity = (multipleLights != null && multipleLights.Length > 0 && multipleLights[0] != null) ? multipleLights[0].intensity : 1f;
        InitSlider(multiRangeSlider,     0f, 30f, initRange);
        InitSlider(multiIntensitySlider, 0f, 5f,  initIntensity);

        if (directionalToggle != null)    directionalToggle.onValueChanged.AddListener(OnDirectionalToggle);
        if (ambientSlider != null)        ambientSlider.onValueChanged.AddListener(v => RenderSettings.ambientIntensity = v);
        if (shadowStrengthSlider != null) shadowStrengthSlider.onValueChanged.AddListener(v => { if (directionalLight != null) directionalLight.shadowStrength = v; });
        if (dirIntensitySlider != null)   dirIntensitySlider.onValueChanged.AddListener(v => { if (directionalLight != null) directionalLight.intensity = v; });
        if (rotXSlider != null)           rotXSlider.onValueChanged.AddListener(v => { rotX = v; ApplyRotation(); });
        if (rotYSlider != null)           rotYSlider.onValueChanged.AddListener(v => { rotY = v; ApplyRotation(); });

        if (multipleLightsToggle != null)
        {
            bool initMulti = multipleLightsParent != null && multipleLightsParent.gameObject.activeSelf;
            multipleLightsToggle.SetIsOnWithoutNotify(initMulti);
            multipleLightsToggle.onValueChanged.AddListener(OnMultipleLightsToggle);
        }
        if (multiRangeSlider != null)     multiRangeSlider.onValueChanged.AddListener(OnMultiRangeChanged);
        if (multiIntensitySlider != null) multiIntensitySlider.onValueChanged.AddListener(OnMultiIntensityChanged);

        // 초기 상태 동기화 — 토글 값에 맞춰 그룹/메시지 표시
        OnDirectionalToggle(directionalToggle != null ? directionalToggle.isOn : (directionalLight != null && directionalLight.gameObject.activeSelf));
        OnMultipleLightsToggle(multipleLightsToggle != null && multipleLightsToggle.isOn);
    }

    void Update()
    {
        if (rotateMultipleToggle != null && rotateMultipleToggle.isOn
            && multipleLightsParent != null && multipleLightsParent.gameObject.activeInHierarchy)
        {
            multipleLightsParent.Rotate(0f, RotateSpeed * Time.deltaTime, 0f, Space.World);
        }
    }

    void OnDirectionalToggle(bool isOn)
    {
        if (directionalLight != null) directionalLight.gameObject.SetActive(isOn);
        if (directionalControlsGroup   != null) directionalControlsGroup.SetActive(isOn);
        if (directionalDisabledMessage != null) directionalDisabledMessage.SetActive(!isOn);
        SetToggleLabelColor(directionalToggle, isOn);
    }

    void OnMultipleLightsToggle(bool isOn)
    {
        if (multipleLightsParent      != null) multipleLightsParent.gameObject.SetActive(isOn);
        if (multiControlsGroup        != null) multiControlsGroup.SetActive(isOn);
        if (multiDisabledMessage      != null) multiDisabledMessage.SetActive(!isOn);
        SetToggleLabelColor(multipleLightsToggle, isOn);
    }

    void OnMultiRangeChanged(float v)
    {
        if (multipleLights == null) return;
        for (int i = 0; i < multipleLights.Length; i++)
            if (multipleLights[i] != null) multipleLights[i].range = v;
    }

    void OnMultiIntensityChanged(float v)
    {
        if (multipleLights == null) return;
        for (int i = 0; i < multipleLights.Length; i++)
            if (multipleLights[i] != null) multipleLights[i].intensity = v;
    }

    void ApplyRotation()
    {
        if (directionalLight != null)
            directionalLight.transform.rotation = Quaternion.Euler(rotX, rotY, 0f);
    }

    static readonly Color LabelActiveColor   = Color.white;
    static readonly Color LabelInactiveColor = new Color(0.5f, 0.5f, 0.5f, 1f);

    static void SetToggleLabelColor(Toggle toggle, bool isOn)
    {
        if (toggle == null) return;
        var labelTr = toggle.transform.Find("Label");
        if (labelTr == null) return;
        var tmp = labelTr.GetComponent<TMPro.TextMeshProUGUI>();
        if (tmp != null) tmp.color = isOn ? LabelActiveColor : LabelInactiveColor;
    }

    // 재귀 검색 — 그룹(MultiControlsGroup/DirectionalControlsGroup) 안의 컨트롤도 찾을 수 있게.
    // includeInactive=true: 비활성 그룹의 자식도 매칭 (UI 초기화 시점에 그룹이 꺼져있어도 OK)
    Toggle FindToggle(string goName)
    {
        var toggles = GetComponentsInChildren<Toggle>(true);
        foreach (var t in toggles)
            if (t.gameObject.name == goName) return t;
        return null;
    }

    Slider FindSlider(string rowName)
    {
        var sliders = GetComponentsInChildren<Slider>(true);
        foreach (var s in sliders)
            if (s.transform.parent != null && s.transform.parent.name == rowName)
                return s;
        return null;
    }

    static void InitSlider(Slider s, float min, float max, float val)
    {
        if (s == null) return;
        s.minValue = min;
        s.maxValue = max;
        s.SetValueWithoutNotify(val);
    }

    static float NormalizeAngle(float deg)
    {
        deg %= 360f;
        if (deg > 180f) deg -= 360f;
        if (deg < -180f) deg += 360f;
        return deg;
    }
}
