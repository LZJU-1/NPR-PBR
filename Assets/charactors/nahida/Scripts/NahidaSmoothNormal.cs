using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// 平滑法线烘焙 — 解决硬边处描边断裂。
///
/// 原理：
///   同一位置有多个顶点（各面不同法线）→ 描边外扩时张开断裂。
///   把这些顶点的法线简单相加取平均，存入 mesh.tangents，
///   Outline Pass 改用 tangent 外扩 → 硬边法线平滑 → 描边连续。
///
/// 使用：
///   1. 在 Hierarchy 中选中带 SkinnedMeshRenderer 的 GameObject
///   2. 将此脚本拖上去（或通过菜单 Component 添加）
///   3. 右键脚本标题 → "执行平滑"
///   4. 看到 Console 打印完成后，Ctrl+S 保存场景
/// </summary>
[RequireComponent(typeof(SkinnedMeshRenderer))]
public class NahidaSmoothNormal : MonoBehaviour
{
    /// <summary>
    /// 在 Edit Mode 下右键脚本组件执行，不需要进 Play Mode
    /// </summary>
    [ContextMenu("执行平滑")]
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

        Vector3[] vertices = mesh.vertices;
        Vector3[] normals  = mesh.normals;

        // 1. 按坐标分组：同一位置的顶点属于同一平滑组
        var groups = new Dictionary<Vector3, List<int>>();
        for (int i = 0; i < vertices.Length; i++)
        {
            if (!groups.ContainsKey(vertices[i]))
                groups[vertices[i]] = new List<int>();
            groups[vertices[i]].Add(i);
        }

        // 2. 对每组法线直接相加取平均（教程方式）
        Vector4[] smoothTangents = new Vector4[vertices.Length];

        foreach (var group in groups)
        {
            if (group.Value.Count == 1)
            {
                // 孤立顶点 → 原法线
                int i = group.Value[0];
                smoothTangents[i] = new Vector4(normals[i].x, normals[i].y,
                                                  normals[i].z, 1f);
                continue;
            }

            // 简单相加
            Vector3 sum = Vector3.zero;
            foreach (int i in group.Value)
                sum += normals[i];

            sum.Normalize();

            foreach (int i in group.Value)
                smoothTangents[i] = new Vector4(sum.x, sum.y, sum.z, 1f);
        }

        // 3. 写入 mesh.uv2（天然支持负数，不需要编解码）
        var uv2List = new List<Vector3>(vertices.Length);
        for (int i = 0; i < vertices.Length; i++)
            uv2List.Add(new Vector3(smoothTangents[i].x, smoothTangents[i].y,
                                     smoothTangents[i].z));
        mesh.SetUVs(1, uv2List);

        int smoothGroupCount = 0;
        foreach (var g in groups)
            if (g.Value.Count > 1) smoothGroupCount++;

        Debug.Log($"[NahidaSmoothNormal] 完成 — {vertices.Length} 个顶点, " +
                  $"{smoothGroupCount} 个平滑组。现在可移除本脚本。");
    }
}
