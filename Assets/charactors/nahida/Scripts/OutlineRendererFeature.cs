using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.Universal;

/// <summary>
/// URP Renderer Feature — 屏幕空间边缘检测描边（Unity 6 RenderGraph API）。
///
/// 在 Opaque 渲染完成后，使用深度 + 法线纹理做 Sobel 边缘检测，
/// 将检测到的边缘以 _OutlineColor 颜色叠加到屏幕上。
/// </summary>
public class OutlineRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class OutlineSettings
    {
        public Material        edgeDetectMaterial;
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
        _pass.Setup(settings.edgeDetectMaterial);
        renderer.EnqueuePass(_pass);
    }

    private class OutlineRenderPass : ScriptableRenderPass
    {
        private Material         _material;
        private OutlineSettings  _settings;

        private static readonly int OutlineColorId   = Shader.PropertyToID("_OutlineColor");
        private static readonly int ThresholdId       = Shader.PropertyToID("_Threshold");
        private static readonly int NormalThresholdId = Shader.PropertyToID("_NormalThreshold");
        private static readonly int OutlineWidthId    = Shader.PropertyToID("_OutlineWidth");

        public OutlineRenderPass(OutlineSettings settings)
        {
            _settings = settings;
            renderPassEvent = settings.renderPassEvent;
            requiresIntermediateTexture = false;
        }

        public void Setup(Material mat)
        {
            _material = mat;
            ConfigureInput(ScriptableRenderPassInput.Depth |
                           ScriptableRenderPassInput.Normal);
        }

        // Unity 6 / URP 17 新 API
        public override void RecordRenderGraph(RenderGraph renderGraph,
                                                ContextContainer frameData)
        {
            if (_material == null) return;

            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            UniversalCameraData   cameraData   = frameData.Get<UniversalCameraData>();

            if (resourceData.cameraColor.IsValid() &&
                resourceData.cameraDepth.IsValid())
            {
                // 先拷贝当前画面到临时纹理
                var camColor = resourceData.cameraColor;

                TextureDesc desc = renderGraph.GetTextureDesc(camColor);
                desc.name     = "_OutlineEdgeTex";
                desc.format   = camColor.GetDescriptor(renderGraph).format;
                desc.clearBuffer = false;

                var edgeTex = renderGraph.CreateTexture(desc);

                // 材质参数
                var texelSize = new Vector4(
                    1.0f / cameraData.camera.scaledPixelWidth,
                    1.0f / cameraData.camera.scaledPixelHeight,
                    cameraData.camera.scaledPixelWidth,
                    cameraData.camera.scaledPixelHeight);

                _material.SetFloat(ThresholdId,       0.5f);
                _material.SetFloat(NormalThresholdId, 0.4f);
                _material.SetFloat(OutlineWidthId,    1.0f);
                _material.SetVector("_CameraDepthTexture_TexelSize", texelSize);

                // Pass 0: 拷贝 cameraColor → edgeTex
                using (var builder = renderGraph.AddRasterRenderPass(
                    "Outline Copy", out var passData))
                {
                    passData.sourceTex = camColor;
                    passData.targetTex = edgeTex;

                    builder.UseTexture(camColor, AccessFlags.Read);
                    builder.SetRenderAttachment(edgeTex, 0, AccessFlags.Write);
                    builder.AllowPassCulling(false);

                    builder.SetRenderFunc((CopyPassData data, RasterGraphContext ctx) =>
                    {
                        Blitter.BlitCameraTexture(ctx.cmd, data.sourceTex, data.targetTex,
                                                  RenderBufferLoadAction.DontCare,
                                                  RenderBufferStoreAction.Store,
                                                  Vector2.one, Vector2.zero);
                    });
                }

                // Pass 1: 边缘检测（edgeTex → cameraColor）
                using (var builder = renderGraph.AddRasterRenderPass(
                    "Outline Detect", out var passData2))
                {
                    passData2.sourceTex = edgeTex;
                    passData2.targetTex = camColor;
                    passData2.material  = _material;

                    builder.UseTexture(edgeTex,  AccessFlags.Read);
                    builder.SetRenderAttachment(camColor, 0, AccessFlags.Write);
                    builder.AllowPassCulling(false);

                    builder.SetRenderFunc((DetectPassData data, RasterGraphContext ctx) =>
                    {
                        // 把源纹理设到 _MainTex 供 Blitter 使用
                        ctx.cmd.SetGlobalTexture("_BlitTexture", data.sourceTex);
                        Blitter.BlitCameraTexture(ctx.cmd, data.sourceTex, data.targetTex,
                                                  data.material, 0);
                    });
                }
            }
        }

        private class CopyPassData
        {
            public TextureHandle sourceTex;
            public TextureHandle targetTex;
        }

        private class DetectPassData
        {
            public TextureHandle sourceTex;
            public TextureHandle targetTex;
            public Material      material;
        }
    }
}
