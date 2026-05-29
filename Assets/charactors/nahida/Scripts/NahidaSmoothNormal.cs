using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 平滑法线烘焙 — 解决硬边描边断裂。
///
/// 同位置多顶点取加权平均法线（面积权重），存入 mesh.uv3，
/// Outline Pass 通过 TEXCOORD2 读取。
/// </summary>
[RequireComponent(typeof(SkinnedMeshRenderer))]
public class NahidaSmoothNormal : MonoBehaviour
{
    [Header("权重")]
    [Tooltip("勾选=按三角面积加权（大面对平滑方向影响更大）")]
    public bool useAreaWeight = true;

    [ContextMenu("执行平滑")]
    private void Awake() { SmoothAndBake(); }

    public void SmoothAndBake()
    {
        var rend = GetComponent<SkinnedMeshRenderer>();
        if (rend == null)
        {
            Debug.LogError("[NahidaSmoothNormal] 未找到 SkinnedMeshRenderer。");
            return;
        }

        Mesh mesh = rend.sharedMesh;
        if (mesh == null)
        {
            Debug.LogError("[NahidaSmoothNormal] 未找到 Mesh。");
            return;
        }

        Vector3[] vertices  = mesh.vertices;
        Vector3[] normals   = mesh.normals;
        int[]     triangles = mesh.triangles;

        // ---- 1. 按坐标分组 ----
        var groups = new Dictionary<Vector3, List<int>>();
        for (int i = 0; i < vertices.Length; i++)
        {
            if (!groups.ContainsKey(vertices[i]))
                groups[vertices[i]] = new List<int>();
            groups[vertices[i]].Add(i);
        }

        // ---- 2. 计算顶点面积权重 ----
        // 三角形面积 = 0.5 × |AB × AC|
        // 每个顶点累加其所属所有三角形的面积
        float[] weights = null;
        if (useAreaWeight)
        {
            weights = new float[vertices.Length];
            for (int t = 0; t < triangles.Length; t += 3)
            {
                int    i0 = triangles[t];
                int    i1 = triangles[t + 1];
                int    i2 = triangles[t + 2];
                float area = Vector3.Cross(vertices[i1] - vertices[i0],
                                           vertices[i2] - vertices[i0]).magnitude * 0.5f;
                weights[i0] += area;
                weights[i1] += area;
                weights[i2] += area;
            }
        }

        // ---- 3. 加权平均 ----
        Vector4[] smoothTangents = new Vector4[vertices.Length];

        foreach (var group in groups)
        {
            if (group.Value.Count == 1)
            {
                int i = group.Value[0];
                smoothTangents[i] = new Vector4(normals[i].x, normals[i].y,
                                                  normals[i].z, 1f);
                continue;
            }

            Vector3 sum   = Vector3.zero;
            float   total = 0f;

            foreach (int i in group.Value)
            {
                float w = useAreaWeight ? weights[i] : 1f;
                sum   += normals[i] * w;
                total += w;
            }

            sum = (total > 0f) ? (sum / total).normalized : sum.normalized;

            foreach (int i in group.Value)
                smoothTangents[i] = new Vector4(sum.x, sum.y, sum.z, 1f);
        }

        // ---- 4. 写入 mesh.uv3 (TEXCOORD2) ----
        var uv3List = new List<Vector4>(vertices.Length);
        for (int i = 0; i < vertices.Length; i++)
            uv3List.Add(smoothTangents[i]);
        mesh.SetUVs(2, uv3List);

        int smoothCount = 0;
        foreach (var g in groups) if (g.Value.Count > 1) smoothCount++;

        Debug.Log($"[NahidaSmoothNormal] 完成 — {vertices.Length} 顶点, " +
                  $"{smoothCount} 个平滑组" +
                  (useAreaWeight ? ", 面积加权" : ", 平均"));
    }
}
