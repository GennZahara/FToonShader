using UnityEngine;
using UnityEngine.UI;

/// 캐릭터 턴테이블 — 토글로 캐릭터를 Y축 자동 회전.
/// 캐릭터가 돌면 빛/카메라가 고정이어도 각도 의존 기능(림라이트, MatCap,
/// Kajiya-Kay, SDF 그림자)을 전 각도에서 확인할 수 있음.
///
/// UI (자식에서 이름으로 검색):
///   Toggle "Rotate Character" — 자동 회전 ON/OFF
///   Slider "Rotate Speed"     — 회전 속도 (°/s, 범위는 코드에서 설정)
///   Button "Reset Rotation"   — 시작 시점 회전값으로 복원 (선택)
public class CharacterTurntableController : MonoBehaviour
{
    [SerializeField] Transform target;   // 비워두면 FeelPanelContext.CharacterRoot 사용

    const float DefaultSpeed = 30f;      // °/s

    Toggle rotateToggle;
    Slider speedSlider;
    Button resetButton;

    Quaternion initialRotation;
    bool rotationCaptured;

    void Awake()
    {
        if (target == null)
        {
            var context = GetComponentInParent<FeelPanelContext>(true);
            if (context == null) context = FindObjectOfType<FeelPanelContext>(true);
            if (context != null) target = context.CharacterRoot;
        }
        if (target == null)
        {
            Debug.LogWarning($"{nameof(CharacterTurntableController)}: target not set.");
        }
        else
        {
            initialRotation  = target.rotation;
            rotationCaptured = true;
        }

        rotateToggle = FindToggle("Rotate Character");
        speedSlider  = FindSlider("Rotate Speed");
        resetButton  = FindButton("Reset Rotation");

        InitSlider(speedSlider, 0f, 180f, DefaultSpeed);
        if (resetButton != null) resetButton.onClick.AddListener(ResetRotation);
    }

    void Update()
    {
        if (target == null || rotateToggle == null || !rotateToggle.isOn) return;

        float speed = speedSlider != null ? speedSlider.value : DefaultSpeed;
        target.Rotate(0f, speed * Time.deltaTime, 0f, Space.World);
    }

    public void ResetRotation()
    {
        if (target != null && rotationCaptured) target.rotation = initialRotation;
    }

    // 재귀 검색 — LightPanelController와 동일한 패턴 (비활성 자식 포함)
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

    Button FindButton(string goName)
    {
        var buttons = GetComponentsInChildren<Button>(true);
        foreach (var b in buttons)
            if (b.gameObject.name == goName) return b;
        return null;
    }

    static void InitSlider(Slider s, float min, float max, float val)
    {
        if (s == null) return;
        s.minValue = min;
        s.maxValue = max;
        s.SetValueWithoutNotify(val);
    }
}
