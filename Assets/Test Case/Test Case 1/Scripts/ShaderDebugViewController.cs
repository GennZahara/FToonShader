using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

/// 셰이더 디버그 뷰 — 어느 메시에 어떤 Feel 셰이더가 적용됐는지 단색으로 표시.
///
/// 토글 ON  → characterRoot 아래 모든 렌더러의 sharedMaterials를
///            셰이더 종류별 단색 Unlit 머티리얼로 교체 (원본 배열은 캡처)
/// 토글 OFF → 캡처해둔 원본 배열 복원
///
/// 색상 매핑 (인스펙터에서 변경 가능):
///   Feel_Main → 초록 / Feel_Face → 노랑 / Feel_Hair → 파랑 / Feel_Eye → 빨강
///   그 외 셰이더 → 회색
///
/// 주의: 디버그 뷰가 켜진 상태에서 FeelPanelContext.SetCharacterRoot()를 호출하면
///       캡처본이 stale해지므로, 캐릭터 교체 전에 토글을 꺼야 함.
public class ShaderDebugViewController : MonoBehaviour
{
    // FeelPanelContext와 동일한 셰이더 이름 기준
    const string ShaderMain = "Custom/Feel_Main";
    const string ShaderFace = "Custom/Feel_Face";
    const string ShaderHair = "Custom/Feel_Hair";
    const string ShaderEye  = "Custom/Feel_Eye";

    const string ToggleName = "Shader Debug View";

    [SerializeField] Toggle debugToggle;   // 비워두면 자식에서 "Shader Debug View" 이름으로 검색

    [Header("Shader Colors")]
    [SerializeField] Color mainColor  = new Color(0.20f, 0.80f, 0.35f);
    [SerializeField] Color faceColor  = new Color(1.00f, 0.80f, 0.20f);
    [SerializeField] Color hairColor  = new Color(0.25f, 0.55f, 1.00f);
    [SerializeField] Color eyeColor   = new Color(1.00f, 0.30f, 0.45f);
    [SerializeField] Color otherColor = new Color(0.45f, 0.45f, 0.45f);

    FeelPanelContext context;
    readonly Dictionary<Renderer, Material[]> originals = new Dictionary<Renderer, Material[]>();
    readonly Dictionary<string, Material> debugMats = new Dictionary<string, Material>();
    bool active;

    void Awake()
    {
        context = GetComponentInParent<FeelPanelContext>(true);
        if (context == null) context = FindObjectOfType<FeelPanelContext>(true);
        if (context == null)
        {
            Debug.LogError($"{nameof(ShaderDebugViewController)}: FeelPanelContext not found in hierarchy.");
            return;
        }

        if (debugToggle == null)
        {
            var toggles = GetComponentsInChildren<Toggle>(true);
            foreach (var t in toggles)
                if (t.gameObject.name == ToggleName) { debugToggle = t; break; }
        }

        if (debugToggle != null)
        {
            debugToggle.SetIsOnWithoutNotify(false);
            debugToggle.onValueChanged.AddListener(SetDebugView);
        }
        else
        {
            Debug.LogWarning($"{nameof(ShaderDebugViewController)}: Toggle \"{ToggleName}\" not found.");
        }
    }

    public void SetDebugView(bool on)
    {
        if (on) ApplyDebugView();
        else    RestoreOriginals();
    }

    void ApplyDebugView()
    {
        if (active) return;
        if (context == null || context.CharacterRoot == null)
        {
            Debug.LogError($"{nameof(ShaderDebugViewController)}: characterRoot not set.");
            if (debugToggle != null) debugToggle.SetIsOnWithoutNotify(false);
            return;
        }

        var renderers = context.CharacterRoot.GetComponentsInChildren<Renderer>(true);
        foreach (var r in renderers)
        {
            var shared = r.sharedMaterials;
            if (shared == null || shared.Length == 0) continue;

            originals[r] = shared;

            var debug = new Material[shared.Length];
            for (int i = 0; i < shared.Length; i++)
                debug[i] = GetDebugMaterial(shared[i]);
            r.sharedMaterials = debug;
        }
        active = true;
    }

    void RestoreOriginals()
    {
        if (!active) return;
        foreach (var kvp in originals)
            if (kvp.Key != null) kvp.Key.sharedMaterials = kvp.Value;
        originals.Clear();
        active = false;
    }

    Material GetDebugMaterial(Material src)
    {
        string key = (src != null && src.shader != null) ? src.shader.name : "";
        if (key != ShaderMain && key != ShaderFace && key != ShaderHair && key != ShaderEye)
            key = "";   // Feel 셰이더가 아니면 전부 "기타" 버킷

        if (debugMats.TryGetValue(key, out var cached) && cached != null)
            return cached;

        var unlit = Shader.Find("Universal Render Pipeline/Unlit");
        if (unlit == null)
        {
            Debug.LogError($"{nameof(ShaderDebugViewController)}: URP Unlit shader not found.");
            return src;
        }

        var mat = new Material(unlit)
        {
            name = $"DebugView_{(key == "" ? "Other" : key.Substring(key.LastIndexOf('/') + 1))}"
        };
        mat.SetColor("_BaseColor", ColorForShader(key));
        debugMats[key] = mat;
        return mat;
    }

    Color ColorForShader(string shaderName)
    {
        switch (shaderName)
        {
            case ShaderMain: return mainColor;
            case ShaderFace: return faceColor;
            case ShaderHair: return hairColor;
            case ShaderEye:  return eyeColor;
            default:         return otherColor;
        }
    }

    // 컨트롤러/캔버스가 비활성화돼도 머티리얼이 디버그 색으로 남지 않도록 복원
    void OnDisable()
    {
        RestoreOriginals();
        if (debugToggle != null) debugToggle.SetIsOnWithoutNotify(false);
    }

    void OnDestroy()
    {
        RestoreOriginals();
        foreach (var kvp in debugMats)
            if (kvp.Value != null) Destroy(kvp.Value);
        debugMats.Clear();
    }
}
