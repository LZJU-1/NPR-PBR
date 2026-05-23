using UnityEngine;

[RequireComponent(typeof(SkinnedMeshRenderer))]
public class NahidaFaceScripts : MonoBehaviour
{
    [Header("Bone / Marker paths (relative to this transform)")]
    [Tooltip("e.g. Nahida/Nahida_arm/Bip001/.../Head")]
    public string headBonePath;

    [Tooltip("e.g. Nahida/Nahida_arm/Bip001/.../Head/HeadForward")]
    public string headForwardPath;

    [Tooltip("e.g. Nahida/Nahida_arm/Bip001/.../Head/HeadRight")]
    public string headRightPath;

    [Header("Face material indices")]
    [Tooltip("Which material slots on the SkinnedMeshRenderer belong to the face.")]
    public int[] faceMaterialIndices = { 0, 1, 5, 6, 7, 8, 16 };

    // cached
    private Transform _headBone;
    private Transform _headForward;
    private Transform _headRight;
    private Material[] _faceMaterials;

    private static readonly int ForwardVectorId = Shader.PropertyToID("_ForwardVector");
    private static readonly int RightVectorId   = Shader.PropertyToID("_RightVector");

    void Start()
    {
        ResolveTransforms();
        CollectFaceMaterials();
        Update(); // set vectors immediately, avoid one-frame delay
    }

    void Update()
    {
        if (_faceMaterials == null || _headBone == null || _headForward == null || _headRight == null)
            return;

        Vector3 headPos = _headBone.position;

        Vector3 forward = (_headForward.position - headPos).normalized;
        Vector3 right   = (_headRight.position - headPos).normalized;

        // orthogonalize to match shader: up = cross(forward, right)
        Vector3 up = Vector3.Cross(forward, right);
        right = Vector3.Cross(up, forward).normalized;

        Vector4 fwd4 = forward;
        Vector4 rgt4 = right;

        foreach (var mat in _faceMaterials)
        {
            if (mat == null) continue;
            mat.SetVector(ForwardVectorId, fwd4);
            mat.SetVector(RightVectorId,   rgt4);
        }
    }

    // ---- resolve transforms --------------------------------------------------

    void ResolveTransforms()
    {
        // head bone
        if (!string.IsNullOrEmpty(headBonePath))
            _headBone = transform.Find(headBonePath);
        if (_headBone == null)
            _headBone = FindRecursive(transform.root, "joint_Head");
        if (_headBone == null)
            _headBone = FindRecursive(transform.root, "Head");
        if (_headBone == null)
            _headBone = FindRecursiveEndsWith(transform.root, "joint_Head");

        if (_headBone == null)
        {
            Debug.LogError("[NahidaFaceScripts] head bone not found. Set headBonePath or ensure 'joint_Head' exists.");
            return;
        }

        // forward marker
        if (!string.IsNullOrEmpty(headForwardPath))
            _headForward = transform.Find(headForwardPath);
        if (_headForward == null)
            _headForward = _headBone.Find("HeadForward");
        if (_headForward == null)
            Debug.LogError("[NahidaFaceScripts] 'HeadForward' not found under head bone.");

        // right marker
        if (!string.IsNullOrEmpty(headRightPath))
            _headRight = transform.Find(headRightPath);
        if (_headRight == null)
            _headRight = _headBone.Find("HeadRight");
        if (_headRight == null)
            Debug.LogError("[NahidaFaceScripts] 'HeadRight' not found under head bone.");
    }

    void CollectFaceMaterials()
    {
        var rend = GetComponent<SkinnedMeshRenderer>();
        var all = rend.materials;

        if (faceMaterialIndices == null || faceMaterialIndices.Length == 0)
        {
            Debug.LogError("[NahidaFaceScripts] faceMaterialIndices is empty.");
            return;
        }

        _faceMaterials = new Material[faceMaterialIndices.Length];
        for (int i = 0; i < faceMaterialIndices.Length; i++)
        {
            int idx = faceMaterialIndices[i];
            if (idx >= 0 && idx < all.Length)
                _faceMaterials[i] = all[idx];
            else
                Debug.LogWarning($"[NahidaFaceScripts] material index {idx} out of range (total {all.Length}).");
        }
    }

    // ---- utils ---------------------------------------------------------------

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

#if UNITY_EDITOR
    void OnDrawGizmosSelected()
    {
        // attempt lazy resolve for gizmo preview
        if (_headBone == null) ResolveTransforms();

        if (_headBone == null) return;

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
        if (_headForward != null && _headRight != null)
        {
            Vector3 forward = (_headForward.position - _headBone.position).normalized;
            Vector3 right   = (_headRight.position - _headBone.position).normalized;
            Vector3 up      = Vector3.Cross(forward, right);
            right = Vector3.Cross(up, forward).normalized;

            float len = 0.05f;
            Gizmos.color = Color.blue;  Gizmos.DrawRay(_headBone.position, forward * len);
            Gizmos.color = Color.red;   Gizmos.DrawRay(_headBone.position, right * len);
            Gizmos.color = Color.green; Gizmos.DrawRay(_headBone.position, up * len);
        }
    }
#endif
}
