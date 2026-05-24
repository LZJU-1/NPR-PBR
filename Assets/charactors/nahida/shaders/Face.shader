Shader "Unlit/Face"
{
    Properties
    {
        // ================================================================
        // 光照颜色
        // ================================================================
        _AmbientColor ("Ambient Color", Color) = (0.667, 0.667, 0.667, 1)
        _DiffuseColor ("Diffuse Color", Color) = (0.906, 0.906, 0.906, 1)
        _ShadowColor  ("Shadow Color",  Color) = (0.737, 0.737, 0.737, 1)

        // ================================================================
        // 贴图
        // _BaseTex: 脸部漫反射贴图 → tex/颜.png
        // _ToonTex: MatCap 风格卡通光照贴图 → tex/toon_defo.bmp（sampler 使用 matcapUV）
        // _SphereTex: MatCap 球面反射贴图 → tex/s1.bmp（sampler 使用 matcapUV）
        // _RampTex: 脸部阴影 Ramp 贴图 → universals/Avatar_Tex_Face_Shadow.png
        // _SDF: 脸部方向阴影贴图 → universals/Avatar_Loli_Tex_FaceLightmap.png
        // ================================================================
        _BaseTexFac ("Base Tex Fac", Range(0, 1)) = 1
        [MainTexture] _BaseTex ("Base Tex", 2D) = "white" {}
        _ToonTexFac ("Toon Tex Fac", Range(0, 1)) = 1
        _ToonTex ("Toon Tex", 2D) = "white" {}
        _SphereTexFac ("Sphere Tex Fac", Range(0, 1)) = 0
        _SphereTex ("Sphere Tex", 2D) = "white" {}
        _SphereMulAdd ("Sphere Mul/Add", Range(0, 1)) = 0

        // _RampRow: 选择 Ramp 贴图中第几行（1~5），值 = row/10 - 0.05
        // 脸部通常使用第 5 行（暖色调阴影过渡）
        _RampTex ("Ramp Tex", 2D) = "white" {}
        _RampRow ("Ramp Row", Range(1, 5)) = 5

        // _SDF: 存储脸部每个像素的阴影阈值（R 通道 0~1）
        // 与 NahidaFaceScripts 传入的 _ForwardVector/_RightVector 配合使用
        _SDF ("SDF", 2D) = "black" {}
        _ForwardVector ("Forward Vector", Vector) = (0, 0, 1, 0)
        _RightVector   ("Right Vector",   Vector) = (1, 0, 0, 0)

        // ================================================================
        // 其他参数
        // ================================================================
        _DoubleSided ("Double Sided", Range(0, 1)) = 0
        _Alpha ("Alpha", Range(0, 1)) = 1
        _OutlineOffset ("Outline Offset", Float) = 0.000015
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }
        LOD 100

        // ================================================================
        // Pass 0: ShadowCaster — 向 Shadow Map 写入深度
        // ================================================================
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        // ================================================================
        // Pass 1: DepthNormals — 供 SSAO、后处理描边等屏幕空间特效使用
        // ================================================================
        Pass
        {
            Name "DepthNormals"
            Tags { "LightMode" = "DepthNormals" }

            ZWrite On
            Cull Off

            HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5
            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        // ================================================================
        // Pass 2: UniversalForward — 主渲染通道（脸部 NPR + SDF 阴影）
        // ================================================================
        Pass
        {
            Name "DrawObject"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            // ------------------------------------------------------------
            // 顶点/片元结构
            // ------------------------------------------------------------
            struct Attributes
            {
                float4 vertex  : POSITION;
                float2 uv      : TEXCOORD0;
                float3 normal  : NORMAL;
                float4 tangent : TANGENT;
                float4 color   : COLOR0;
            };

            struct Varyings
            {
                float2 uv           : TEXCOORD0;
                float3 positionWS   : TEXCOORD1;
                float3 positionVS   : TEXCOORD2;
                float4 positionCS   : SV_POSITION;
                float3 positionNDC  : TEXCOORD3;
                float3 normalWS     : TEXCOORD4;
                float3 tangentWS    : TEXCOORD5;
                float3 bitangentWS  : TEXCOORD6;
                float  fogCoord     : TEXCOORD7;
                float4 shadowCoord  : TEXCOORD8;
            };

            // ------------------------------------------------------------
            // Material 属性常量缓冲区
            // ------------------------------------------------------------
            CBUFFER_START(UnityPerMaterial)
                float4 _AmbientColor, _DiffuseColor, _ShadowColor;
                float  _BaseTexFac, _ToonTexFac, _SphereTexFac, _SphereMulAdd;
                float4 _BaseTex_ST;
                float  _DoubleSided, _Alpha;
                float  _RampRow;
                float  _OutlineOffset;
                float3 _ForwardVector, _RightVector;
            CBUFFER_END

            // 贴图与采样器声明 — 与 Properties 块中贴图一一对应
            TEXTURE2D(_BaseTex);    SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ToonTex);    SAMPLER(sampler_ToonTex);
            TEXTURE2D(_SphereTex);  SAMPLER(sampler_SphereTex);
            TEXTURE2D(_RampTex);    SAMPLER(sampler_RampTex);
            TEXTURE2D(_SDF);        SAMPLER(sampler_SDF);

            // ------------------------------------------------------------
            // 顶点着色器
            // ------------------------------------------------------------
            Varyings vert(Attributes input)
            {
                Varyings output;

                VertexPositionInputs posInput = GetVertexPositionInputs(input.vertex.xyz);
                output.uv          = TRANSFORM_TEX(input.uv, _BaseTex);
                output.positionWS  = posInput.positionWS;
                output.positionVS  = posInput.positionVS;
                output.positionCS  = posInput.positionCS;
                output.positionNDC = posInput.positionNDC;

                VertexNormalInputs normInput = GetVertexNormalInputs(input.normal, input.tangent);
                output.normalWS     = normInput.normalWS;
                output.tangentWS    = normInput.tangentWS;
                output.bitangentWS  = normInput.bitangentWS;

                output.fogCoord    = ComputeFogFactor(output.positionCS.z);
                output.shadowCoord = TransformWorldToShadowCoord(posInput.positionWS);

                return output;
            }

            // ------------------------------------------------------------
            // 片元着色器 — 脸部 NPR（卡通渲染）
            //
            // 渲染流程：
            //   1. 基础色 — Ambient + Diffuse 混合，叠乘 BaseTex、ToonTex
            //   2. Ramp 阴影色 — 从 Face_Shadow.png 暗色端采样
            //   3. SDF 阴影形状 — FaceLightmap.png + 光源方向 → 硬切蒙版
            //   4. 合成 — sdf=1(亮面)用 baseColor，sdf=0(暗面)用 shadowColor
            //
            // 贴图用途：
            //   _BaseTex   → 颜.png             脸部漫反射
            //   _ToonTex   → toon_defo.bmp      MatCap 卡通光照叠加
            //   _RampTex   → Face_Shadow.png    阴影颜色 Ramp（只用暗色端）
            //   _SDF       → FaceLightmap.png   SDF 阴影阈值（R 通道）
            //   _SphereTex → s1.bmp             球面反射（当前 _SphereTexFac=0 关闭）
            //
            // _ForwardVector / _RightVector 由 NahidaFaceScripts.cs 每帧写入
            // ------------------------------------------------------------
            float4 frag(Varyings input, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                Light light = GetMainLight(input.shadowCoord);

                // ---- 光照方向向量 ----
                float3 N = normalize(input.normalWS);
                float3 L = normalize(light.direction);

                // ---- MatCap UV（用于 ToonTex 采样）----
                float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, N));
                float2 matcapUV = normalVS.xy * 0.5 + 0.5;

                // ---- 贴图采样 ----
                float4 baseTex   = SAMPLE_TEXTURE2D(_BaseTex,   sampler_BaseTex,   input.uv);
                float4 toonTex   = SAMPLE_TEXTURE2D(_ToonTex,   sampler_ToonTex,   matcapUV);
                float4 sphereTex = SAMPLE_TEXTURE2D(_SphereTex, sampler_SphereTex, matcapUV);

                // ====================================================
                // 1. 基础色计算
                //    AmbientColor 为暗面色调，lerp 混入 DiffuseColor
                //    再叠乘漫反射贴图、MatCap 贴图、球面反射贴图
                // ====================================================
                float3 baseColor = _AmbientColor.rgb;
                baseColor = saturate(lerp(baseColor, baseColor + _DiffuseColor.rgb, 0.6));
                baseColor = lerp(baseColor, baseColor * baseTex.rgb,   _BaseTexFac);
                baseColor = lerp(baseColor, baseColor * toonTex.rgb,   _ToonTexFac);
                baseColor = lerp(
                    lerp(baseColor, baseColor * sphereTex.rgb,      _SphereTexFac),
                    lerp(baseColor, baseColor + sphereTex.rgb,      _SphereTexFac),
                    _SphereMulAdd);

                // ====================================================
                // 2. Ramp 阴影颜色
                //    从 Face_Shadow.png 的指定行（_RampRow）暗色端采样
                //    U=0.003(最暗端), V=行选择
                //    日夜两套：Night 行 = Day 行 + 0.5 纵向偏移
                // ====================================================
                float rampV       = _RampRow / 10.0 - 0.05;
                float rampClampMin = 0.003;
                float2 rampDayUV   = float2(rampClampMin, 1.0 - rampV);
                float2 rampNightUV = float2(rampClampMin, 1.0 - (rampV + 0.5));
                float  isDay       = (L.y + 1.0) / 2.0;
                float3 rampColor   = lerp(
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampNightUV).rgb,
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDayUV).rgb,
                    isDay);

                // ====================================================
                // 3. SDF 脸部方向阴影蒙版
                //
                // 将光源方向投影到头部水平面 → 计算与 rightVec 夹角
                // → 立方函数映射为阈值 mixValue → 与 SDF 贴图像素值比较
                //
                // SDF 贴图 (FaceLightmap.png, R 通道):
                //   存储每个像素的"阴影触发角度阈值"
                //   当 mixValue >= mixSdf 时该像素处于阴影中
                // ====================================================
                float3 forwardVec = _ForwardVector;
                float3 rightVec   = _RightVector;

                float3 upVector  = cross(forwardVec, rightVec);
                float  sqrUpLen  = dot(upVector, upVector);
                float3 LpU       = sqrUpLen > 1e-12
                                   ? dot(L, upVector) / sqrUpLen * upVector
                                   : float3(0, 0, 0);
                float3 LpHead    = L - LpU;

                float sdf = 1.0; // 默认全亮
                float LpHeadLen = length(LpHead);

                if (LpHeadLen > 1e-5)
                {
                    float3 LpHeadDir = LpHead / LpHeadLen;

                    float cosAngle = dot(LpHeadDir, normalize(rightVec));
                    cosAngle = clamp(cosAngle, -1.0, 1.0);
                    float angle01 = acos(cosAngle) / 3.1415926;

                    float exposRight = step(angle01, 0.5);

                    float valueR = pow(saturate(1.0 - angle01 * 2.0), 3);
                    float valueL = pow(saturate(angle01 * 2.0 - 1.0), 3);
                    float mixValue = lerp(valueL, valueR, exposRight);

                    float sdfLeft  = SAMPLE_TEXTURE2D(_SDF, sampler_SDF,
                                        float2(1.0 - input.uv.x, input.uv.y)).r;
                    float sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, input.uv).r;
                    float mixSdf   = lerp(sdfRight, sdfLeft, exposRight);

                    float sdfRaw = step(mixValue, mixSdf);
                    sdf = lerp(1.0, sdfRaw,
                               step(0.0, dot(LpHeadDir, normalize(forwardVec))));
                }

                // ====================================================
                // 4. 合成
                //    sdf=1(亮面) → baseColor
                //    sdf=0(暗面) → baseColor × rampColor × ShadowColor
                // ====================================================
                float3 shadowColor = baseColor * rampColor * _ShadowColor.rgb;
                float3 finalColor  = lerp(shadowColor, baseColor, sdf);

                float alpha = _Alpha * baseTex.a;
                alpha = saturate(min(max(isFacing, _DoubleSided), alpha));

                float4 col = float4(finalColor, alpha);
                clip(col.a - 0.5);
                col.rgb = MixFog(col.rgb, input.fogCoord);

                return col;
            }
            ENDHLSL
        }
    }
}
