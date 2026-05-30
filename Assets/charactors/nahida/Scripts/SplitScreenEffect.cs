using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// 挂到 Main Camera 上，在渲染结束后叠加分割线效果。
/// 当前仅显示分割线，等 PBR 模式完成后比较 NPR vs PBR。
/// </summary>
[RequireComponent(typeof(Camera))]
public class SplitScreenEffect : MonoBehaviour
{
    public Material splitMaterial;

    private void OnEnable()
    {
        RenderPipelineManager.endCameraRendering += OnEndCameraRendering;
    }

    private void OnDisable()
    {
        RenderPipelineManager.endCameraRendering -= OnEndCameraRendering;
    }

    void OnEndCameraRendering(ScriptableRenderContext context, Camera camera)
    {
        if (camera != GetComponent<Camera>() || splitMaterial == null) return;

        var cmd = CommandBufferPool.Get("SplitScreen");
        // Blit 用 splitMaterial 做全屏后处理
        cmd.Blit(null, BuiltinRenderTextureType.CameraTarget, splitMaterial);
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }
}
