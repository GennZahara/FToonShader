using UnityEngine;
using UnityEngine.UI;

/// Reset 버튼 — 모든 런타임 머티리얼을 원본 에셋 값으로 복원하고 패널 UI를 갱신.
///
/// 버튼 클릭 → FeelPanelContext.ResetAllMaterials()
///           → 씬의 모든 FeelPanelControllerBase.RefreshUI() (초기화 안 된 패널은 무시됨)
public class ResetButtonController : MonoBehaviour
{
    const string ButtonName = "Reset All";

    [SerializeField] Button resetButton;   // 비워두면 자식에서 "Reset All" 이름으로 검색

    FeelPanelContext context;

    void Awake()
    {
        context = GetComponentInParent<FeelPanelContext>(true);
        if (context == null) context = FindObjectOfType<FeelPanelContext>(true);
        if (context == null)
        {
            Debug.LogError($"{nameof(ResetButtonController)}: FeelPanelContext not found in hierarchy.");
            return;
        }

        if (resetButton == null)
        {
            var buttons = GetComponentsInChildren<Button>(true);
            foreach (var b in buttons)
                if (b.gameObject.name == ButtonName) { resetButton = b; break; }
        }

        if (resetButton != null)
            resetButton.onClick.AddListener(ResetAll);
        else
            Debug.LogWarning($"{nameof(ResetButtonController)}: Button \"{ButtonName}\" not found.");
    }

    public void ResetAll()
    {
        if (context == null) return;

        context.ResetAllMaterials();

        // 모든 패널 UI를 복원된 머티리얼 값으로 동기화 (비활성 패널 포함)
        var panels = FindObjectsOfType<FeelPanelControllerBase>(true);
        foreach (var p in panels)
            p.RefreshUI();

        // 디버그 출력 드롭다운도 Off로 동기화 (_DebugMode는 위 리셋으로 이미 0)
        var debugOutput = FindObjectOfType<ShaderDebugOutputController>(true);
        if (debugOutput != null) debugOutput.ResetToOff();
    }
}
