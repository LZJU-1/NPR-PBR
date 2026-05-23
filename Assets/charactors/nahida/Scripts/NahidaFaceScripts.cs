using UnityEngine;

/// <summary>
/// 向脸部材质传递头部方向向量，用于 SDF 面部阴影计算。
///
/// 原理：
/// Face.shader 中的 SDF 阴影需要知道角色头部的"前方"和"右方"方向，
/// 以便将光源方向投影到头部平面，计算光源相对于脸部的角度。
/// 该角度与 SDF 贴图（FaceLightmap）对比，决定每个像素处于亮面还是暗面。
///
/// 用法：
/// 将此脚本挂到含有 SkinnedMeshRenderer 的 GameObject 上，
/// 在头骨下创建 HeadForward / HeadRight 两个空子物体作为方向标记。
/// </summary>
[RequireComponent(typeof(SkinnedMeshRenderer))]
public class NahidaFaceScripts : MonoBehaviour
{
    [Header("骨骼 / 标记物路径（相对于此 Transform）")]
    [Tooltip("头骨骼路径，留空则自动搜索名为 joint_Head 或 Head 的骨骼")]
    public string headBonePath;

    [Tooltip("前方标记物路径，留空则自动搜索头骨下的 HeadForward 子物体")]
    public string headForwardPath;

    [Tooltip("右方标记物路径，留空则自动搜索头骨下的 HeadRight 子物体")]
    public string headRightPath;

    [Header("脸部材质")]
    [Tooltip("SkinnedMeshRenderer 上哪些材质槽属于脸部，需要接收方向向量")]
    public int[] faceMaterialIndices = { 0, 1, 5, 6, 7, 8, 16 };

    // 缓存的 Transform 引用
    private Transform _headBone;
    private Transform _headForward;
    private Transform _headRight;
    private Material[] _faceMaterials;

    // Shader 属性 ID（缓存避免字符串查找）
    private static readonly int ForwardVectorId = Shader.PropertyToID("_ForwardVector");
    private static readonly int RightVectorId   = Shader.PropertyToID("_RightVector");

    void Start()
    {
        ResolveTransforms();
        CollectFaceMaterials();
        Update(); // 立即设置一帧，避免第一帧面部阴影错误
    }

    void Update()
    {
        if (_faceMaterials == null || _headBone == null ||
            _headForward == null || _headRight == null)
            return;

        // 从标记物位置计算头部方向向量
        Vector3 headPos = _headBone.position;
        Vector3 forward = (_headForward.position - headPos).normalized;
        Vector3 right   = (_headRight.position   - headPos).normalized;

        // 正交化：以 forward 为准，修正 right 与之垂直
        // 与 Face.shader 中 upVector = cross(forwardVec, rightVec) 保持一致
        Vector3 up = Vector3.Cross(forward, right);
        right = Vector3.Cross(up, forward).normalized;

        // 写入所有脸部材质
        foreach (var mat in _faceMaterials)
        {
            if (mat == null) continue;
            mat.SetVector(ForwardVectorId, forward);
            mat.SetVector(RightVectorId,   right);
        }
    }

    // ================================================================
    // 骨骼与标记物查找
    // ================================================================

    void ResolveTransforms()
    {
        // 1. 查找头骨：优先用 Inspector 填写的路径，否则自动搜索
        if (!string.IsNullOrEmpty(headBonePath))
            _headBone = transform.Find(headBonePath);
        if (_headBone == null)
            _headBone = FindRecursive(transform.root, "joint_Head");
        if (_headBone == null)
            _headBone = FindRecursive(transform.root, "Head");
        // MMD 模型导入后骨骼名可能带数字前缀（如 12.joint_Head），
        // 用 EndsWith 做兜底匹配
        if (_headBone == null)
            _headBone = FindRecursiveEndsWith(transform.root, "joint_Head");

        if (_headBone == null)
        {
            Debug.LogError("[NahidaFaceScripts] 未找到头骨。" +
                           "请在 Inspector 设置 headBonePath，或确保骨骼名为 joint_Head / Head。");
            return;
        }

        // 2. 查找前方标记物：同样优先路径，否则搜头骨的直接子级
        if (!string.IsNullOrEmpty(headForwardPath))
            _headForward = transform.Find(headForwardPath);
        if (_headForward == null)
            _headForward = _headBone.Find("HeadForward");
        if (_headForward == null)
            Debug.LogError("[NahidaFaceScripts] 未在头骨下找到 HeadForward。");

        // 3. 查找右方标记物
        if (!string.IsNullOrEmpty(headRightPath))
            _headRight = transform.Find(headRightPath);
        if (_headRight == null)
            _headRight = _headBone.Find("HeadRight");
        if (_headRight == null)
            Debug.LogError("[NahidaFaceScripts] 未在头骨下找到 HeadRight。");
    }

    /// <summary>
    /// 从 SkinnedMeshRenderer 按索引收集脸部材质引用。
    /// 注意：renderer.materials 会实例化材质副本，确保运行时修改不影响原始资源。
    /// 只在 Start() 中调用一次，之后 Update() 使用缓存的引用。
    /// </summary>
    void CollectFaceMaterials()
    {
        var rend = GetComponent<SkinnedMeshRenderer>();
        if (rend == null)
        {
            Debug.LogError("[NahidaFaceScripts] 未找到 SkinnedMeshRenderer。");
            return;
        }

        var all = rend.materials;

        if (faceMaterialIndices == null || faceMaterialIndices.Length == 0)
        {
            Debug.LogError("[NahidaFaceScripts] faceMaterialIndices 为空。");
            return;
        }

        _faceMaterials = new Material[faceMaterialIndices.Length];
        for (int i = 0; i < faceMaterialIndices.Length; i++)
        {
            int idx = faceMaterialIndices[i];
            if (idx >= 0 && idx < all.Length)
                _faceMaterials[i] = all[idx];
            else
                Debug.LogWarning($"[NahidaFaceScripts] 材质索引 {idx} 超出范围（共 {all.Length} 个）。");
        }
    }

    // ================================================================
    // 递归搜索工具
    // ================================================================

    /// <summary>在 Transform 层级中按名称精确匹配查找</summary>
    Transform FindRecursive(Transform parent, string name)
    {
        if (parent.name == name)
            return parent;
        for (int i = 0; i < parent.childCount; i++)
        {
            var found = FindRecursive(parent.GetChild(i), name);
            if (found != null) return found;
        }
        return null;
    }

    /// <summary>在 Transform 层级中按名称后缀匹配查找（用于兼容带前缀的骨骼名）</summary>
    Transform FindRecursiveEndsWith(Transform parent, string suffix)
    {
        if (parent.name.EndsWith(suffix))
            return parent;
        for (int i = 0; i < parent.childCount; i++)
        {
            var found = FindRecursiveEndsWith(parent.GetChild(i), suffix);
            if (found != null) return found;
        }
        return null;
    }

    // ================================================================
    // Editor Gizmo（仅 Unity 编辑器下可见）
    // ================================================================

#if UNITY_EDITOR
    void OnDrawGizmosSelected()
    {
        if (_headBone == null) ResolveTransforms();
        if (_headBone == null) return;

        // 标记物位置球
        if (_headForward != null)
        {
            Gizmos.color = Color.blue;
            Gizmos.DrawLine(_headBone.position, _headForward.position);
            Gizmos.DrawWireSphere(_headForward.position, 0.003f);
        }
        if (_headRight != null)
        {
            Gizmos.color = Color.red;
            Gizmos.DrawLine(_headBone.position, _headRight.position);
            Gizmos.DrawWireSphere(_headRight.position, 0.003f);
        }

        // 头部局部坐标系射线（蓝=前 红=右 绿=上）
        if (_headForward != null && _headRight != null)
        {
            Vector3 forward = (_headForward.position - _headBone.position).normalized;
            Vector3 right   = (_headRight.position   - _headBone.position).normalized;
            Vector3 up      = Vector3.Cross(forward, right);
            right = Vector3.Cross(up, forward).normalized;

            float len = 0.05f;
            Gizmos.color = Color.blue;  Gizmos.DrawRay(_headBone.position, forward * len);
            Gizmos.color = Color.red;   Gizmos.DrawRay(_headBone.position, right   * len);
            Gizmos.color = Color.green; Gizmos.DrawRay(_headBone.position, up      * len);
        }
    }
#endif
}
