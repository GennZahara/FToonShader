using UnityEngine;
using UnityEngine.EventSystems;

/// 오빗 카메라 — 메인 카메라에 부착.
///   우클릭 드래그 : 피벗 중심 회전 (UI 클릭과 충돌하지 않도록 우클릭 사용)
///   중클릭 드래그 : 패닝 (피벗을 카메라 평면에서 이동 — 비중심 부위를 화면 중앙으로)
///   마우스 휠     : 줌 인/아웃 (포인터가 UI 위에 있으면 무시)
///
/// pivot을 비워두면 FeelPanelContext.CharacterRoot를 사용.
/// 시작 시점의 카메라 위치를 기준으로 yaw/pitch/distance를 초기화하므로,
/// 씬에서 잡아둔 카메라 구도가 그대로 시작 구도가 됨.
public class OrbitCameraController : MonoBehaviour
{
    [SerializeField] Transform pivot;            // 비워두면 FeelPanelContext.CharacterRoot
    [SerializeField] float pivotHeight = 1.0f;   // 캐릭터 pivot이 발밑일 때 시선 높이 보정

    [Header("Orbit")]
    [SerializeField] float rotateSpeed = 5f;     // 마우스 축 단위당 회전(°)
    [SerializeField] float minPitch = -80f;
    [SerializeField] float maxPitch =  80f;

    [Header("Zoom")]
    [SerializeField] float zoomSpeed   = 1.0f;   // 휠 한 칸(0.1)당 거리 10% 변화
    [SerializeField] float minDistance = 0.3f;
    [SerializeField] float maxDistance = 20f;

    [Header("Pan")]
    [SerializeField] float panSpeed = 0.5f;      // 마우스 축 단위당 패닝량 (거리에 비례)

    float yaw, pitch, distance;
    Vector3 panOffset;   // 피벗 기준 누적 패닝 이동(월드 공간)
    bool dragging;
    bool panning;

    void Start()
    {
        if (pivot == null)
        {
            var context = FindObjectOfType<FeelPanelContext>(true);
            if (context != null) pivot = context.CharacterRoot;
        }
        if (pivot == null)
        {
            Debug.LogWarning($"{nameof(OrbitCameraController)}: pivot not set — disabled.");
            enabled = false;
            return;
        }

        // 현재 카메라 위치 → yaw/pitch/distance 역산
        Vector3 offset = transform.position - PivotPoint();
        distance = Mathf.Clamp(offset.magnitude, minDistance, maxDistance);
        yaw      = Mathf.Atan2(-offset.x, -offset.z) * Mathf.Rad2Deg;
        pitch    = Mathf.Asin(Mathf.Clamp(offset.y / Mathf.Max(distance, 0.001f), -1f, 1f)) * Mathf.Rad2Deg;
        Apply();
    }

    void LateUpdate()
    {
        if (pivot == null) return;

        bool overUI = EventSystem.current != null && EventSystem.current.IsPointerOverGameObject();

        // 우클릭 드래그 — UI 위에서 시작한 드래그는 무시, 버튼을 떼면 종료
        if (Input.GetMouseButtonDown(1) && !overUI) dragging = true;
        if (!Input.GetMouseButton(1)) dragging = false;

        if (dragging)
        {
            yaw   += Input.GetAxis("Mouse X") * rotateSpeed;
            pitch -= Input.GetAxis("Mouse Y") * rotateSpeed;
            pitch  = Mathf.Clamp(pitch, minPitch, maxPitch);
        }

        // 중클릭 드래그 — 패닝 (grab 방식: 드래그한 방향으로 모델이 따라옴)
        // UI 위에서 시작한 드래그는 무시, 버튼을 떼면 종료
        if (Input.GetMouseButtonDown(2) && !overUI) panning = true;
        if (!Input.GetMouseButton(2)) panning = false;

        if (panning)
        {
            // 거리에 비례시켜 줌 레벨과 무관하게 일정한 패닝 감도 유지
            panOffset -= (transform.right * Input.GetAxis("Mouse X")
                        + transform.up    * Input.GetAxis("Mouse Y")) * panSpeed * distance * 0.1f;
        }

        float scroll = Input.GetAxis("Mouse ScrollWheel");
        if (!Mathf.Approximately(scroll, 0f) && !overUI)
            distance = Mathf.Clamp(distance * (1f - scroll * zoomSpeed), minDistance, maxDistance);

        Apply();
    }

    Vector3 PivotPoint() => pivot.position + Vector3.up * pivotHeight + panOffset;

    // 패닝 누적값 초기화 — 시점을 캐릭터 중심으로 되돌림 (버튼 등에 연결 가능)
    public void ResetPan() => panOffset = Vector3.zero;

    void Apply()
    {
        Quaternion rot = Quaternion.Euler(pitch, yaw, 0f);
        transform.position = PivotPoint() + rot * new Vector3(0f, 0f, -distance);
        transform.rotation = rot;
    }
}
