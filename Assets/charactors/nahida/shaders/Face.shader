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

        // _SDF: SDF 阴影阈值贴图（R 通道），决定阴影形状
        // _ShadowTex: 阴影调制贴图（与 _SDF 同一张 FaceLightmap.png）
        //   G 通道 — 阴影强度衰减（脸颊、眼窝等处减淡阴影）
        //   A 通道 — 强制高亮遮罩（鼻梁、额头中心等永不落阴影）
        // 与 NahidaFaceScripts 传入的 _ForwardVector/_RightVector 配合使用
        _SDF ("SDF", 2D) = "black" {}
        _ShadowTex ("Shadow Tex", 2D) = "black" {}
        _ForwardVector ("Forward Vector", Vector) = (0, 0, 1, 0)
        _RightVector   ("Right Vector",   Vector) = (1, 0, 0, 0)

        // ================================================================
        // 其他参数
        // ================================================================
        _DoubleSided ("Double Sided", Range(0, 1)) = 0
        _Alpha ("Alpha", Range(0, 1)) = 1

        // ---- 描边（背面膨胀法 / Inverted Hull Outline）----
        // _OutlineColor:  描边颜色，RGBA 的 A 必须 = 1 否则透明不可见
        // _OutlineOffset: 顶点沿法线外扩距离（模型空间单位），值越大描边越粗
        //                 对 Nahida 模型（约 1.5m 高）推荐 0.0005~0.002
        _OutlineColor  ("Outline Color",  Color) = (0, 0, 0, 1)
        _OutlineOffset ("Outline Offset", Float) = 0.0003
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
                float4 _RimColor;
                float  _RimPower, _RimIntensity;
                float3 _ForwardVector, _RightVector;
            CBUFFER_END

            // 贴图与采样器声明 — 与 Properties 块中贴图一一对应
            TEXTURE2D(_BaseTex);    SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ToonTex);    SAMPLER(sampler_ToonTex);
            TEXTURE2D(_SphereTex);  SAMPLER(sampler_SphereTex);
            TEXTURE2D(_RampTex);    SAMPLER(sampler_RampTex);
            TEXTURE2D(_SDF);        SAMPLER(sampler_SDF);
            TEXTURE2D(_ShadowTex);  SAMPLER(sampler_ShadowTex);

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
                float3 V = normalize(mul((float3x3)UNITY_MATRIX_I_V, input.positionVS * (-1.0)));
                float  NoV = dot(N, V);

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
                //    U=0.003 取 Ramp 最暗端暖色，避免中间冷色调偏绿
                //    日夜两套：Night 行 = Day 行 + 0.5 纵向偏移
                // ====================================================
                float rampV        = _RampRow / 10.0 - 0.05;
                float rampU        = 0.003;
                float2 rampDayUV   = float2(rampU, 1.0 - rampV);
                float2 rampNightUV = float2(rampU, 1.0 - (rampV + 0.5));
                float  isDay       = (L.y + 1.0) / 2.0;
                float3 rampColor   = lerp(
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampNightUV).rgb,
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDayUV).rgb,
                    isDay);

                // ====================================================
                // 3. SDF 脸部方向阴影
                //
                // FaceLightmap.png 四通道含义：
                //   R — SDF 阴影阈值：像素被判定为阴影所需的光源角度阈值
                //   G — 阴影强度衰减：局部减淡阴影（如脸颊、眼窝）
                //   B — 高光遮罩（当前未使用）
                //   A — 强制高亮遮罩：鼻梁、额头中心等凸起处永不落阴影
                //
                // 计算流程：
                //   光源方向投影到头部水平面 → 夹角 → 立方映射 → 阈值
                //   → step 硬切产生 sdf 蒙版 → G 通道减淡 → A 通道提亮
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

                    // _SDF (FaceLightmap.png R 通道): SDF 阴影阈值
                    // 根据光源侧别翻转 UV 的 U 方向
                    float sdfLeft  = SAMPLE_TEXTURE2D(_SDF, sampler_SDF,
                                        float2(1.0 - input.uv.x, input.uv.y)).r;
                    float sdfRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, input.uv).r;
                    float mixSdf   = lerp(sdfRight, sdfLeft, exposRight);

                    float sdfRaw = step(mixValue, mixSdf);

                    // 光源在头部后方时强制全亮
                    sdf = lerp(1.0, sdfRaw,
                               step(0.0, dot(LpHeadDir, normalize(forwardVec))));

                    // _ShadowTex (FaceLightmap.png GA 通道): 阴影调制
                    // G — 阴影强度衰减，A — 强制高亮遮罩
                    float4 shadowTex = SAMPLE_TEXTURE2D(_ShadowTex, sampler_ShadowTex,
                                                        input.uv);
                    sdf *= shadowTex.g;
                    sdf = lerp(sdf, 1.0, shadowTex.a);
                }

                // ====================================================
                // 4. 合成
                //    sdf=1 → 亮面 baseColor
                //    sdf=0 → 暗面 baseColor × rampColor × ShadowColor
                //    sdf=中间值 → G 通道产生的柔和过渡
                // ====================================================
                float3 shadowColor = baseColor * rampColor * _ShadowColor.rgb;
                float3 diffuse     = lerp(shadowColor, baseColor, sdf);

                // ---- 边缘光（菲涅尔）----
                float fresnel = 1.0 - saturate(NoV);
                fresnel = pow(fresnel, _RimPower);
                diffuse += fresnel * _RimIntensity * _RimColor.rgb;

                float alpha = _Alpha * baseTex.a * toonTex.a * sphereTex.a;
                alpha = saturate(min(max(isFacing, _DoubleSided), alpha));

                float4 col = float4(diffuse, alpha);
                clip(col.a - 0.5);
                col.rgb = MixFog(col.rgb, input.fogCoord);

                return col;
            }
            ENDHLSL
        }

        // ================================================================
        // Pass 3: DrawOutline — 背面膨胀描边 (Inverted Hull Outline)
        //
        // ---- 几何原理 ----
        //
        // 考虑一个球体：从相机看过去，正面（朝向相机的半球）正常渲染，
        // 背面（背对相机的半球）被 Cull Front 剔除，正常情况下看不到。
        //
        // 但如果把背面的每个顶点沿法线方向向外推一段距离，背面就会膨胀
        // 成一个稍大的球。在球的轮廓边缘处，这个膨胀的背面会"溢出"正面
        // 的边界，从相机视角看形成一圈细线——这就是描边。
        //
        //              相机
        //               │
        //     ╭──────────┼──────────╮  ← 膨胀后的背面（Cull Front 渲染）
        //     │  ╭───────┼───────╮  │
        //     │  │  正面（正常渲染） │  │
        //     │  ╰───────┼───────╯  │
        //     ╰──────────┼──────────╯
        //               │    ↑
        //               │    轮廓处膨胀背面溢出 = 描边
        //
        // 关键设计决策：
        //   1. 膨胀发生在模型空间（vertex.xyz + normal * offset），不依赖相机距离
        //   2. 使用顶点法线（不是面法线），软边缘模型顶点法线平均后会更合理
        //   3. 没有独立的 ZTest/ZWrite，使用默认 LEqual/On，
        //      膨胀背面在正面"后面"→ Z 测试自动被遮挡 → 只留边缘描边
        //
        // ---- Pass 顺序 ----
        //
        // DrawOutline 放在 SubShader 最后一个 Pass（Pass 3），在
        // ShadowCaster → DepthNormals → UniversalForward 之后执行。
        // 顺序影响：
        //   - 先渲染的 Pass（ShadowCaster）只写深度缓冲区，不写颜色
        //   - DepthNormals 同样只写深度/法线缓冲
        //   - UniversalForward 写颜色 + 深度（正面）
        //   - DrawOutline 最后执行，膨胀背面比正面大，边缘溢出形成描边
        //
        // ---- Tags ----
        //
        // 无 "LightMode" 标签。
        // 原因：带 LightMode="SRPDefaultUnlit" 或其他值时，URP 的
        // 渲染循环可能跳过此 Pass（取决于 Renderer 配置和 RenderGraph 模式）。
        // 不指定 LightMode 让 URP 以最兼容的方式处理。
        // ================================================================
        Pass
        {
            Name "DrawOutline"
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"
                "RenderType" = "Opaque"
            }

            // 剔除正面（Cull Front）：只渲染法线背对相机的面。
            // 这些面在模型内部，沿法线外扩后在轮廓处溢出 → 描边。
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog       // 启用雾效变体（FOG_LINEAR/EXP/EXP2）

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            // 此 Pass 独立的常量缓冲区，变量仅本 Pass 可见
            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;   // 描边颜色，材质 Inspector 中设置
                float  _OutlineOffset;  // 外扩距离（模型空间单位），越大描边越粗
            CBUFFER_END

            // 顶点着色器输入：位置 + 法线用于外扩方向
            struct Attributes
            {
                float4 vertex : POSITION;  // 模型空间顶点坐标
                float2 uv     : TEXCOORD0; // UV（本 Pass 未使用，保留兼容性）
                float3 normal : NORMAL;    // 模型空间法线，决定外扩方向
            };

            // 顶点着色器输出 → 片元着色器输入
            struct Varyings
            {
                float2 uv         : TEXCOORD0;
                float4 positionCS : SV_POSITION;  // 裁剪空间坐标，GPU 自动处理光栅化
                float  fogCoord   : TEXCOORD1;    // 雾效坐标，传入 MixFog()
            };

            // ------------------------------------------------------------------
            // 顶点着色器
            // 把背面顶点沿法线向外推 → 膨胀背面 → 边缘溢出形成描边
            // ------------------------------------------------------------------
            Varyings vert(Attributes v)
            {
                Varyings o;

                // 模型空间法线 × 外扩距离 = 偏移量
                // 对于球体：所有顶点沿径向（=法线方向）均匀外扩
                // 对于角色：软边缘处法线平滑，描边连续；硬边处可能断裂
                float3 offset = v.normal.xyz * _OutlineOffset;
                VertexPositionInputs posInput = GetVertexPositionInputs(
                    v.vertex.xyz + offset);

                o.uv         = v.uv;
                o.positionCS = posInput.positionCS;               // 模型→世界→视→裁剪
                o.fogCoord   = ComputeFogFactor(posInput.positionCS.z); // 雾效因子

                return o;
            }

            // ------------------------------------------------------------------
            // 片元着色器
            // 膨胀背面的可见部分（轮廓溢出区域） → 纯色描边
            // ------------------------------------------------------------------
            float4 frag(Varyings i, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                // 不需要光照计算，不需要纹理采样，输出单一颜色即可
                float4 col = _OutlineColor;
                col.rgb = MixFog(col.rgb, i.fogCoord); // 远处描边融入雾色
                return col;
            }
            ENDHLSL
        }
    }
}
