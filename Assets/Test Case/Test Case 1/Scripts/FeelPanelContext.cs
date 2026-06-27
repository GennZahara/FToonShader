using System.Collections.Generic;
using UnityEngine;
using TMPro;

[DefaultExecutionOrder(-100)]
public class FeelPanelContext : MonoBehaviour
{
    const string ShaderMain = "Custom/Feel_Main";
    const string ShaderFace = "Custom/Feel_Face";
    const string ShaderHair = "Custom/Feel_Hair";
    const string ShaderEye  = "Custom/Feel_Eye";

    [Header("Scene References")]
    [SerializeField] Transform characterRoot;
    [SerializeField] TMP_Dropdown functionDropdown;

    [Header("Section GameObjects")]
    [SerializeField] GameObject mainControls;
    [SerializeField] GameObject faceControls;
    [SerializeField] GameObject hairControls;
    [SerializeField] GameObject eyeControls;

    readonly List<Material> mainMaterials = new List<Material>();
    readonly List<Material> faceMaterials = new List<Material>();
    readonly List<Material> hairMaterials = new List<Material>();
    readonly List<Material> eyeMaterials  = new List<Material>();

    // 런타임 복사본 → 원본 에셋 머티리얼 (Reset용)
    readonly Dictionary<Material, Material> runtimeToSource = new Dictionary<Material, Material>();

    public IReadOnlyList<Material> MainMaterials => mainMaterials;
    public IReadOnlyList<Material> FaceMaterials => faceMaterials;
    public IReadOnlyList<Material> HairMaterials => hairMaterials;
    public IReadOnlyList<Material> EyeMaterials  => eyeMaterials;

    public Transform CharacterRoot => characterRoot;
    public TMP_Dropdown FunctionDropdown => functionDropdown;

    void Awake()
    {
        RefreshMaterials();

        if (functionDropdown != null)
        {
            functionDropdown.onValueChanged.AddListener(OnDropdownChanged);
            OnDropdownChanged(functionDropdown.value);
        }
    }

    public void SetCharacterRoot(Transform root)
    {
        // 캐릭터가 바뀌면 이전 캐릭터의 런타임 복사본은 더 이상 쓰이지 않으므로 파기 (누수 방지)
        if (root != characterRoot) DestroyRuntimeCopies();
        characterRoot = root;
        RefreshMaterials();
    }

    // Instantiate로 만든 런타임 복사본을 파기하고 추적 딕셔너리를 비움.
    // (재생 종료 시 Unity가 정리해주지만, 캐릭터 교체가 반복되면 그 사이 인스턴스가 누적되므로 명시적 정리)
    void DestroyRuntimeCopies()
    {
        foreach (var copy in runtimeToSource.Keys)
            if (copy != null) Destroy(copy);
        runtimeToSource.Clear();
    }

    void OnDestroy() => DestroyRuntimeCopies();

    public void RefreshMaterials()
    {
        mainMaterials.Clear();
        faceMaterials.Clear();
        hairMaterials.Clear();
        eyeMaterials.Clear();

        if (characterRoot == null) return;

        var renderers = characterRoot.GetComponentsInChildren<Renderer>(true);
        foreach (var r in renderers)
        {
            var shared = r.sharedMaterials;
            if (shared == null || shared.Length == 0) continue;

            var newMats = new Material[shared.Length];
            bool changed = false;

            for (int i = 0; i < shared.Length; i++)
            {
                var src = shared[i];
                List<Material> bucket = ResolveBucket(src);

                if (bucket != null)
                {
                    // 이미 런타임 복사본이면 재사용 (중복 호출 시 복사본의 복사본 방지)
                    if (runtimeToSource.ContainsKey(src))
                    {
                        newMats[i] = src;
                        bucket.Add(src);
                    }
                    else
                    {
                        var copy = Instantiate(src);
                        copy.name = src.name + " (Runtime)";
                        newMats[i] = copy;
                        bucket.Add(copy);
                        runtimeToSource[copy] = src;
                        changed = true;
                    }
                }
                else
                {
                    newMats[i] = src;
                }
            }

            if (changed) r.sharedMaterials = newMats;
        }
    }

    List<Material> ResolveBucket(Material m)
    {
        if (m == null || m.shader == null) return null;
        switch (m.shader.name)
        {
            case ShaderMain: return mainMaterials;
            case ShaderFace: return faceMaterials;
            case ShaderHair: return hairMaterials;
            case ShaderEye:  return eyeMaterials;
            default:         return null;
        }
    }

    // ===== Reset (런타임 복사본 → 원본 에셋 값으로 복원) =====

    public void ResetAllMaterials()
    {
        foreach (var kvp in runtimeToSource)
            ResetMaterial(kvp.Key, kvp.Value);
    }

    public void ResetMaterials(IReadOnlyList<Material> materials)
    {
        if (materials == null) return;
        for (int i = 0; i < materials.Count; i++)
        {
            var copy = materials[i];
            if (copy != null && runtimeToSource.TryGetValue(copy, out var source))
                ResetMaterial(copy, source);
        }
    }

    static void ResetMaterial(Material copy, Material source)
    {
        if (copy == null || source == null) return;
        copy.CopyPropertiesFromMaterial(source);
        // CopyPropertiesFromMaterial은 키워드를 복사하지 않음 — 별도 복원
        copy.shaderKeywords = source.shaderKeywords;
        copy.renderQueue    = source.renderQueue;
    }

    void OnDropdownChanged(int index)
    {
        SetActiveSafe(mainControls, index == 0);
        SetActiveSafe(faceControls, index == 1);
        SetActiveSafe(hairControls, index == 2);
        SetActiveSafe(eyeControls,  index == 3);
    }

    static void SetActiveSafe(GameObject go, bool active)
    {
        if (go != null && go.activeSelf != active) go.SetActive(active);
    }
}
