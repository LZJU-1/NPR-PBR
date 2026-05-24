using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

/// <summary>
/// URP Renderer Feature — 屏幕空间边缘检测描边。
///
/// 在 Opaque 渲染完成后，使用深度 + 法线纹理做 Sobel 边缘检测，
/// 将检测到的边缘以 _OutlineColor 颜色叠加到屏幕上。
///
/// 需要 URP Renderer 启用了 Depth Texture 和 Normal Texture。
/// 不需要修改任何角色 Shader。
/// </summary>
public class OutlineRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class OutlineSettings
    {
        public Material   edgeDetectMaterial;
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingOpaques;
    }

    public OutlineSettings settings = new OutlineSettings();

    private OutlineRenderPass _pass;

    public override void Create()
    {
        _pass = new OutlineRenderPass(settings);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer,
                                          ref RenderingData renderingData)
    {
        if (settings.edgeDetectMaterial == null) return;

        // 需要深度和法线纹理
        renderer.EnqueuePass(_pass);
    }

    private class OutlineRenderPass : ScriptableRenderPass
    {
        private OutlineSettings _settings;
        private RTHandle         _tempRT;

        private static readonly int TempRTId = Shader.PropertyToID("_OutlineTempRT");

        public OutlineRenderPass(OutlineSettings settings)
        {
            _settings = settings;
            renderPassEvent = settings.renderPassEvent;
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            // 要求深度和法线纹理可用
            ConfigureInput(ScriptableRenderPassInput.Depth |
                           ScriptableRenderPassInput.Normal);

            var desc = renderingData.cameraData.cameraTargetDescriptor;
            desc.depthBufferBits = 0;
            RenderingUtils.ReAllocateIfNeeded(ref _tempRT, desc,
                FilterMode.Point, TextureWrapMode.Clamp, name: "_OutlineTempRT");
        }

        public override void Execute(ScriptableRenderContext context,
                                      ref RenderingData renderingData)
        {
            if (_settings.edgeDetectMaterial == null) return;

            CommandBuffer cmd = CommandBufferPool.Get("OutlineEdgeDetect");

            var cameraTarget = renderingData.cameraData.renderer.cameraColorTargetHandle;

            // 先拷贝当前屏幕到临时 RT
            Blitter.BlitCameraTexture(cmd, cameraTarget, _tempRT);

            // 用边缘检测材质画到屏幕上（会读取 Depth + Normal 纹理）
            Blitter.BlitCameraTexture(cmd, _tempRT, cameraTarget,
                _settings.edgeDetectMaterial, 0);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            _tempRT?.Release();
        }
    }
}
