using UnityEngine;
using UnityEngine.UI;

/// 디렉셔널 라이트가 "어디에서" 비추고 있는지 시각화하는 인디케이터.
/// 캐릭터(pivot) 기준으로 빛이 오는 방향에 태양 오브젝트를 띄우고,
/// +Z(자식 화살표)가 빛 진행 방향(= 캐릭터 쪽)을 향하게 정렬한다.
/// 라이트를 회전시키면(런타임·에디터 모두) 인디케이터가 따라 움직인다.
///
/// 표시/숨김 토글: 씬의 "Show Light Indicator" 토글에 자동 바인딩(플레이 모드).
[ExecuteAlways]
public class LightDirectionIndicator : MonoBehaviour
{
    [SerializeField] Light directionalLight;     // 비우면 "Lighting Mode/Directional Light"로 검색
    [SerializeField] Transform pivot;            // 비우면 FeelPanelContext.CharacterRoot
    [SerializeField] float pivotHeight = 1.0f;   // 캐릭터 pivot이 발밑일 때 시선 높이 보정
    [SerializeField] float radius = 2.6f;        // 캐릭터에서 인디케이터까지 거리
    [SerializeField] bool hideWhenLightOff = true;

    [SerializeField] Toggle visibilityToggle;    // 비우면 "Show Light Indicator"로 검색
    const string ToggleName = "Show Light Indicator";

    bool userVisible = true;
    bool toggleBound;

    void LateUpdate()
    {
        if (directionalLight == null)
        {
            var go = GameObject.Find("Lighting Mode/Directional Light");
            if (go != null) directionalLight = go.GetComponent<Light>();
        }
        if (directionalLight == null) return;

        if (pivot == null)
        {
            var ctx = FindObjectOfType<FeelPanelContext>(true);
            if (ctx != null) pivot = ctx.CharacterRoot;
        }

        TryBindToggle();   // 플레이 모드에서만 1회 바인딩

        // 사용자 토글 + (라이트 켜짐) 둘 다 만족할 때만 비주얼 표시
        bool lightActive = directionalLight.isActiveAndEnabled;
        bool wantVisible = userVisible && (!hideWhenLightOff || lightActive);
        SetVisualsActive(wantVisible);
        if (!wantVisible) return;

        Vector3 center   = (pivot != null ? pivot.position : Vector3.zero) + Vector3.up * pivotHeight;
        Vector3 lightDir = directionalLight.transform.forward;   // 빛이 진행하는 방향
        if (lightDir.sqrMagnitude < 1e-6f) return;

        transform.position = center - lightDir.normalized * radius;  // 빛이 "오는" 위치
        transform.rotation = Quaternion.LookRotation(lightDir);      // +Z = 빛 진행 방향(캐릭터 쪽)
    }

    void TryBindToggle()
    {
        if (toggleBound || !Application.isPlaying) return;
        if (visibilityToggle == null)
        {
            foreach (var t in FindObjectsOfType<Toggle>(true))
                if (t.gameObject.name == ToggleName) { visibilityToggle = t; break; }
        }
        if (visibilityToggle != null)
        {
            userVisible = visibilityToggle.isOn;
            visibilityToggle.onValueChanged.AddListener(v => userVisible = v);
            toggleBound = true;
        }
    }

    void SetVisualsActive(bool on)
    {
        for (int i = 0; i < transform.childCount; i++)
        {
            var c = transform.GetChild(i).gameObject;
            if (c.activeSelf != on) c.SetActive(on);
        }
    }
}
