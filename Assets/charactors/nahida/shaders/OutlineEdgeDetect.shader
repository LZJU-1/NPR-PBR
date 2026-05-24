Shader "Hidden/OutlineEdgeDetect"
{
    // 屏幕空间边缘检测描边 — 使用 Depth + Normal 纹理做 Sobel 滤波
    // 由 OutlineRendererFeature.cs 驱动，在全屏四边形上执行

    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _Threshold    ("Depth Threshold", Range(0.1, 5)) = 0.5
        _NormalThreshold ("Normal Threshold", Range(0.1, 5)) = 0.4
        _OutlineWidth ("Outline Width", Range(1, 4)) = 1
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }

        Cull Off
        ZWrite Off
        ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float4 _OutlineColor;
            float  _Threshold;
            float  _NormalThreshold;
            float  _OutlineWidth;
            float4 _CameraDepthTexture_TexelSize;
        CBUFFER_END

        TEXTURE2D(_CameraDepthTexture);  SAMPLER(sampler_CameraDepthTexture);
        TEXTURE2D(_CameraNormalsTexture); SAMPLER(sampler_CameraNormalsTexture);

        struct Attributes
        {
            float4 vertex   : POSITION;
            float2 uv       : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv         : TEXCOORD0;
        };

        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.vertex.xyz);
            output.uv         = input.uv;
            return output;
        }

        // Sobel 算子 + 深度/法线边缘检测
        float4 Frag(Varyings input) : SV_Target
        {
            float2 texelSize = _CameraDepthTexture_TexelSize.xy * _OutlineWidth;

            // 采样 3x3 邻域的深度
            float dTL = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2(-texelSize.x,  texelSize.y)).r;
            float dT  = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2( 0,             texelSize.y)).r;
            float dTR = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2( texelSize.x,   texelSize.y)).r;
            float dL  = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2(-texelSize.x,   0)).r;
            float dR  = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2( texelSize.x,   0)).r;
            float dBL = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2(-texelSize.x,  -texelSize.y)).r;
            float dB  = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2( 0,            -texelSize.y)).r;
            float dBR = SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture,
                          input.uv + float2( texelSize.x,  -texelSize.y)).r;

            // 深度 Sobel
            float sobelDepthX = -dTL - 2*dL - dBL + dTR + 2*dR + dBR;
            float sobelDepthY = -dTL - 2*dT - dTR + dBL + 2*dB + dBR;
            float depthEdge   = sqrt(sobelDepthX * sobelDepthX + sobelDepthY * sobelDepthY);

            // 法线 Sobel
            float3 nTL = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2(-texelSize.x,  texelSize.y)).rgb;
            float3 nTR = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2( texelSize.x,  texelSize.y)).rgb;
            float3 nBL = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2(-texelSize.x, -texelSize.y)).rgb;
            float3 nBR = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2( texelSize.x, -texelSize.y)).rgb;

            float3 nT  = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2( 0,             texelSize.y)).rgb;
            float3 nL  = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2(-texelSize.x,   0)).rgb;
            float3 nR  = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2( texelSize.x,   0)).rgb;
            float3 nB  = SAMPLE_TEXTURE2D(_CameraNormalsTexture, sampler_CameraNormalsTexture,
                          input.uv + float2( 0,            -texelSize.y)).rgb;

            float3 sobelNormalX = -nTL - 2*nL - nBL + nTR + 2*nR + nBR;
            float3 sobelNormalY = -nTL - 2*nT - nTR + nBL + 2*nB + nBR;
            float  normalEdge   = length(sobelNormalX) + length(sobelNormalY);

            // 综合阈值判定
            float edge = step(_Threshold, depthEdge) + step(_NormalThreshold, normalEdge);
            edge = saturate(edge);

            return edge > 0.0 ? _OutlineColor : float4(0, 0, 0, 0);
        }
        ENDHLSL

        Pass
        {
            Name "OutlineEdgeDetect"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
