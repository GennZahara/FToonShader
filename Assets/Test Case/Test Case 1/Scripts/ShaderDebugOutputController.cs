using System.Collections.Generic;
using TMPro;
using UnityEngine;

/// 셰이더 디버그 출력 — 중간 계산값을 화면에 직접 출력 (_DebugMode 런타임 분기).
///
/// 드롭다운 선택 → 모든 Feel 머티리얼(4종 버킷 전체)의 _DebugMode를 일괄 변경.
/// 단색 뷰(ShaderDebugViewController)와 달리 머티리얼 교체 없이 셰이더 내부에서 분기.
/// 디버그 출력 중에는 Outline 패스도 자동으로 숨겨짐 (Feel_Outline.hlsl discard).
///
/// 모드 (셰이더 _DebugMode 값과 1:1):
///   0 = Off            — 일반 렌더링
///   1 = Shadow Factor  — 셀쉐이딩 1st shadowFactor 흑백 (0=그림자, 1=lit)
///   2 = Normal (World) — 월드 노멀 RGB (Main/Eye는 노멀맵 반영, Face/Hair는 버텍스 노멀)
///   3 = SDF (Face)     — 그림자 판정 raw 값 흑백 + 임계점 컨투어 (빨강=1st, 파랑=2nd).
///                        Face 전용 — 다른 셰이더는 일반 렌더링 유지 (얼굴만 분리되어 보임)
public class ShaderDebugOutputController : MonoBehaviour
{
    const string DropdownName  = "Debug Output";
    const string DebugModeProp = "_DebugMode";

    // 배열 인덱스 = _DebugMode 값. 모드 추가 시 이 배열만 확장하면 됨.
    static readonly string[] ModeNames = { "Off", "Shadow Factor", "Normal (World)", "SDF (Face)" };

    [SerializeField] TMP_Dropdown dropdown;   // 비워두면 자식에서 "Debug Output" 이름으로 검색

    FeelPanelContext context;

    void Awake()
    {
        context = GetComponentInParent<FeelPanelContext>(true);
        if (context == null) context = FindObjectOfType<FeelPanelContext>(true);
        if (context == null)
        {
            Debug.LogError($"{nameof(ShaderDebugOutputController)}: FeelPanelContext not found in hierarchy.");
            return;
        }

        if (dropdown == null)
        {
            var dropdowns = GetComponentsInChildren<TMP_Dropdown>(true);
            foreach (var d in dropdowns)
                if (d.gameObject.name == DropdownName) { dropdown = d; break; }
        }
        if (dropdown == null)
        {
            Debug.LogWarning($"{nameof(ShaderDebugOutputController)}: Dropdown \"{DropdownName}\" not found.");
            return;
        }

        // 옵션은 코드에서 구성 — 씬에는 기본 드롭다운만 있으면 됨
        dropdown.ClearOptions();
        dropdown.AddOptions(new List<string>(ModeNames));
        dropdown.SetValueWithoutNotify(0);
        dropdown.onValueChanged.AddListener(ApplyMode);
    }

    // Reset All 후 호출 — 머티리얼의 _DebugMode는 ResetAllMaterials()가
    // 원본값(0)으로 복원하므로 드롭다운 표시만 동기화
    public void ResetToOff()
    {
        if (dropdown != null) dropdown.SetValueWithoutNotify(0);
    }

    void ApplyMode(int mode)
    {
        if (context == null) return;
        SetMode(context.MainMaterials, mode);
        SetMode(context.FaceMaterials, mode);
        SetMode(context.HairMaterials, mode);
        SetMode(context.EyeMaterials,  mode);
    }

    static void SetMode(IReadOnlyList<Material> mats, float mode)
    {
        if (mats == null) return;
        for (int i = 0; i < mats.Count; i++)
        {
            var m = mats[i];
            if (m != null && m.HasProperty(DebugModeProp)) m.SetFloat(DebugModeProp, mode);
        }
    }
}
