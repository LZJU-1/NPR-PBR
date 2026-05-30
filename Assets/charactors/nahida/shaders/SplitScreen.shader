Shader "NPR/SplitScreen"
{
    // 全屏分割线显示 — 当前仅绘制分割线可视化
    // 等 PBR 模式完成后，左侧采样 PBR RT，右侧采样 NPR RT
    Properties
    {
        _LineWidth ("Line Width", Range(0.001, 0.02)) = 0.004
        _LineColor ("Line Color", Color) = (1, 1, 1, 1)
        _NPRTint   ("NPR Side Tint", Color) = (1, 1, 1, 1)
        _PBRTint   ("PBR Side Tint", Color) = (1, 1, 1, 1)
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
            float  _LineWidth;
            float4 _LineColor;
            float4 _NPRTint;
            float4 _PBRTint;
        CBUFFER_END

        float _SplitLineOffset;
        float2 _SplitLineDir;

        TEXTURE2D(_BlitTexture);
        SAMPLER(sampler_BlitTexture);

        struct Attributes
        {
            float4 vertex : POSITION;
            float2 uv     : TEXCOORD0;
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
            output.uv = input.uv;
            return output;
        }

        float4 Frag(Varyings input) : SV_Target
        {
            // 屏幕中心坐标 [-1, 1]
            float2 screenPos = input.uv * 2.0 - 1.0;

            // 当前像素在分割线的哪一侧
            float side = dot(screenPos, _SplitLineDir) - _SplitLineOffset;

            // 分割线附近的平滑过渡
            float line = 1.0 - smoothstep(0, _LineWidth, abs(side));

            // 当前仅采样同一张 RT（NPR），PBR 模式后替换
            float4 baseColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, input.uv);

            // 分割线两侧色调（当前相同，PBR 后左侧将采样 PBR RT）
            float3 nprColor = baseColor.rgb * _NPRTint.rgb;
            float3 pbrColor = baseColor.rgb * _PBRTint.rgb;

            float3 color = side > 0 ? nprColor : pbrColor;

            // 画分割线
            color = lerp(color, _LineColor.rgb, line);

            return float4(color, 1);
        }
        ENDHLSL

        Pass
        {
            Name "SplitScreen"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
