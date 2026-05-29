Shader "Unlit/BodyAndHair"
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
        // 贴图（详见下方 frag 注释中每张贴图的用途）
        // ================================================================
        _BaseTexFac ("Base Tex Fac", Range(0, 1)) = 1
        [MainTexture] _BaseTex ("Base Tex", 2D) = "white" {}
        _ToonTexFac ("Toon Tex Fac", Range(0, 1)) = 1
        _ToonTex ("Toon Tex", 2D) = "white" {}
        _SphereTexFac ("Sphere Tex Fac", Range(0, 1)) = 0
        _SphereTex ("Sphere Tex", 2D) = "white" {}
        _SphereMulAdd ("Sphere Mul/Add", Range(0, 1)) = 0

        // ---- PBR 高光参数 ----
        _MetalTex    ("Metal Tex",       2D)            = "black" {}
        _SpecExpon   ("Spec Exponent",   Range(1, 128)) = 50
        _KsNonMetallic ("Ks Non-Metallic", Range(0, 3)) = 1
        _KsMetallic  ("Ks Metallic",     Range(0, 3))   = 1

        // ---- NPR 核心贴图 ----
        // _NormalMap: 细节法线贴图 → tex/Body_Normalmap.png（或 Hair_Normalmap.png）
        // _ILM: 光照遮罩贴图 → tex/Body_Lightmap.png（或 Hair_Lightmap.png）
        //   R 通道: 金属度遮罩 (0=非金属 ~ 1=金属)
        //   G 通道: 阴影软硬度 (0=硬阴影 ~ 1=软阴影接全亮)
        //   B 通道: 高光遮罩 (控制非金属高光强度)
        //   A 通道: 材质类型枚举 (0.0/0.3/0.5/0.7/1.0 → 选择 Ramp 行 1~5)
        _NormalMap ("Normal Map", 2D) = "bump" {}
        _ILM ("ILM", 2D) = "black" {}

        // ---- Ramp 阴影渐变 ----
        // _RampTex: 多行 Ramp 贴图 → tex/Body_Shadow_Ramp.png（或 Hair_Shadow_Ramp.png）
        //   横向: 暗色(左) → 亮色(右)，纵向: 5 行对应 5 种材质类型
        //   Row 选择由 ILM.a 通道控制，未设置 ILM 的材质使用下方参数
        _RampTex     ("Ramp Tex",       2D) = "white" {}
        _RampMapRow0 ("Ramp Map Row 0", Range(1, 5)) = 1
        _RampMapRow1 ("Ramp Map Row 1", Range(1, 5)) = 4
        _RampMapRow2 ("Ramp Map Row 2", Range(1, 5)) = 3
        _RampMapRow3 ("Ramp Map Row 3", Range(1, 5)) = 5
        _RampMapRow4 ("Ramp Map Row 4", Range(1, 5)) = 2

        // ================================================================
        // 其他
        // ================================================================
        _DoubleSided  ("Double Sided",  Range(0, 1)) = 0
        _Alpha        ("Alpha",         Range(0, 1)) = 1

        // ---- 边缘光 ----
        _RimOffset       ("Rim Offset",        Range(1, 20))  = 6
        _RimThreshold    ("Rim Threshold",     Range(0, 0.5))  = 0.03
        _RimStrength     ("Rim Strength",      Range(0, 2))    = 0.6
        _RimMax          ("Rim Max",           Range(0, 1))    = 0.3
        _RimFresnelPower ("Rim Fresnel Power", Range(1, 20))   = 6
        _RimFresnelClamp ("Rim Fresnel Clamp", Range(0, 1))    = 0.8

        // ---- 描边 ----
        // _OutlineOffset: 沿法线外扩距离
        // _OutlineMapColor0~4: 5 种 ILM 材质类型的描边颜色，由 ILM.a 选择
        _OutlineOffset    ("Outline Offset",    Float) = 0.001
        _OutlineMapColor0 ("Outline Map Color 0", Color) = (0, 0, 0, 1)
        _OutlineMapColor1 ("Outline Map Color 1", Color) = (0, 0, 0, 1)
        _OutlineMapColor2 ("Outline Map Color 2", Color) = (0, 0, 0, 1)
        _OutlineMapColor3 ("Outline Map Color 3", Color) = (0, 0, 0, 1)
        _OutlineMapColor4 ("Outline Map Color 4", Color) = (0, 0, 0, 1)
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
        // Pass 2: UniversalForward — 主渲染通道（完整 NPR 管线）
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
            // 结构体
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
                float  _SpecExpon, _KsNonMetallic, _KsMetallic;
                float  _RampMapRow0, _RampMapRow1, _RampMapRow2, _RampMapRow3, _RampMapRow4;
                float  _OutlineOffset;
                float  _RimOffset, _RimThreshold, _RimStrength, _RimMax;
                float  _RimFresnelPower, _RimFresnelClamp;
            CBUFFER_END

            // 贴图与采样器 — 与 Properties 块一一对应
            TEXTURE2D(_BaseTex);    SAMPLER(sampler_BaseTex);
            TEXTURE2D(_ToonTex);    SAMPLER(sampler_ToonTex);
            TEXTURE2D(_SphereTex);  SAMPLER(sampler_SphereTex);
            TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
            TEXTURE2D(_ILM);        SAMPLER(sampler_ILM);
            TEXTURE2D(_RampTex);    SAMPLER(sampler_RampTex);
            TEXTURE2D(_MetalTex);   SAMPLER(sampler_MetalTex);

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
            // 片元着色器 — 完整 NPR（卡通渲染）管线
            //
            // 渲染流程（按顺序）：
            //   1. 法线重建 — 采样 NormalMap，变换到世界空间
            //   2. 基础色 — Ambient + Diffuse 混合，叠乘贴图
            //   3. Ramp 阴影 — ILM.a 选行 → halfLambert → Ramp 采样 → step 硬切
            //   4. 高光 — Blinn-Phong，非金属/金属分别处理
            //   5. 金属反射 — MatCap 方式采样 MetalTex
            //   6. 合成 + 雾效
            //
            // 贴图对应关系（身体材质 / 头发材质）：
            //   _BaseTex   → 体1.png / 髮1.png     漫反射
            //   _NormalMap → Body_Normalmap / Hair_Normalmap  细节法线（AG 编码）
            //   _ILM       → Body_Lightmap / Hair_Lightmap    材质遮罩（RGBA）
            //   _RampTex   → Body_Shadow_Ramp / Hair_Shadow_Ramp  阴影渐变
            //   _MetalTex  → MetalMap.png / MetalMap.png     金属反射贴图
            //   _ToonTex   → toon_defo.bmp                   MatCap 光照
            //   _SphereTex → s1.bmp / hair_s.bmp             球面反射
            // ------------------------------------------------------------
            float4 frag(Varyings input, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                Light light = GetMainLight(input.shadowCoord);

                // ====================================================
                // 1. 法线重建
                // ====================================================
                // 从 NormalMap 的 AG 通道解码切线空间法线（BC5 压缩格式）
                // A→X, G→Y，Z 由单位长度约束反推
                float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, input.uv);
                float3 normalTS  = float3(normalMap.ag * 2.0 - 1.0, 0.0);
                normalTS.z = sqrt(1.0 - dot(normalTS.xy, normalTS.xy));

                // 构建 TBN 矩阵，将法线从切线空间变换到世界空间
                float3 N = normalize(mul(normalTS, float3x3(
                    input.tangentWS, input.bitangentWS, input.normalWS)));
                float3 V = normalize(mul((float3x3)UNITY_MATRIX_I_V, input.positionVS * (-1.0)));
                float3 L = normalize(light.direction);
                float3 H = normalize(V + L);

                float NoL = dot(N, L);
                float NoH = dot(N, H);
                float NoV = dot(N, V);

                // ---- MatCap UV ----
                float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, N));
                float2 matcapUV = normalVS.xy * 0.5 + 0.5;

                // ---- 贴图采样 ----
                float4 baseTex   = SAMPLE_TEXTURE2D(_BaseTex,   sampler_BaseTex,   input.uv);
                float4 toonTex   = SAMPLE_TEXTURE2D(_ToonTex,   sampler_ToonTex,   matcapUV);
                float4 sphereTex = SAMPLE_TEXTURE2D(_SphereTex, sampler_SphereTex, matcapUV);

                // ====================================================
                // 2. 基础色计算
                //   从 AmbientColor（暗面色调）出发，混入 DiffuseColor（亮面色调），
                //   再依次叠乘漫反射贴图、MatCap 贴图、球面反射贴图
                // ====================================================
                float3 baseColor = _AmbientColor.rgb;
                baseColor = saturate(lerp(baseColor, baseColor + _DiffuseColor.rgb, 0.6));
                baseColor = lerp(baseColor, baseColor * baseTex.rgb,   _BaseTexFac);
                baseColor = lerp(baseColor, baseColor * toonTex.rgb,   _ToonTexFac);
                // _SphereMulAdd: 0=乘(反射减弱)  1=加(反射增亮)
                baseColor = lerp(
                    lerp(baseColor, baseColor * sphereTex.rgb,      _SphereTexFac),
                    lerp(baseColor, baseColor + sphereTex.rgb,      _SphereTexFac),
                    _SphereMulAdd);

                // ====================================================
                // 3. Ramp 阴影计算
                //   3a. 根据 ILM.a（材质类型枚举）选择 Ramp 贴图中的行
                //   3b. 用 halfLambert 作为光照强度，在 Ramp 行中采样颜色
                //   3c. smoothstep 硬切产生卡通阴影分界
                //   3d. ILM.g 控制阴影软硬度
                // ====================================================

                // ---- 3a. ILM 贴图 & Ramp 行选择 ----
                float4 ilm = SAMPLE_TEXTURE2D(_ILM, sampler_ILM, input.uv);

                // 5 种材质类型的枚举值（对应 ILM.a 的范围分界）
                float matEnum0 = 0.0;
                float matEnum1 = 0.3;
                float matEnum2 = 0.5;
                float matEnum3 = 0.7;
                float matEnum4 = 1.0;

                // 将 RampMapRow 参数转换为贴图 V 坐标（贴图纵向 5 行均匀分布）
                float ramp0 = _RampMapRow0 / 10.0 - 0.05;
                float ramp1 = _RampMapRow1 / 10.0 - 0.05;
                float ramp2 = _RampMapRow2 / 10.0 - 0.05;
                float ramp3 = _RampMapRow3 / 10.0 - 0.05;
                float ramp4 = _RampMapRow4 / 10.0 - 0.05;

                // 根据 ILM.a 在 5 个枚举值之间 lerp 级联，选出当前像素的 Ramp 行
                float dayRampV = lerp(ramp4, ramp3, step(ilm.a, (matEnum3 + matEnum4) / 2.0));
                dayRampV = lerp(dayRampV, ramp2, step(ilm.a, (matEnum2 + matEnum3) / 2.0));
                dayRampV = lerp(dayRampV, ramp1, step(ilm.a, (matEnum1 + matEnum2) / 2.0));
                dayRampV = lerp(dayRampV, ramp0, step(ilm.a, (matEnum0 + matEnum1) / 2.0));

                // Night Ramp = Day Ramp 下移 0.5（Ramp 贴图下半部分为夜间配色）
                float nightRampV = dayRampV + 0.5;

                // ---- 3b. 光照强度 → Ramp U 坐标 ----
                float lambert     = max(0.0, NoL);
                float halfLambert = pow(lambert * 0.5 + 0.5, 2.0);

                // ---- 3c. 硬切分界 ----
                // smoothstep(0.423, 0.450, halfLambert):
                //   光照 > 0.450 → 1（亮面）
                //   光照 < 0.423 → 0（暗面）
                //   中间过渡 → 0~1 渐变
                float lambertStep = smoothstep(0.423, 0.450, halfLambert);

                float rampClampMin = 0.003;
                float rampClampMax = 0.997;

                // 亮面 Ramp: U 随光照强度变化
                float rampGrayU = clamp(
                    smoothstep(0.2, 0.4, halfLambert), rampClampMin, rampClampMax);
                float2 rampGrayDayUV   = float2(rampGrayU, 1.0 - dayRampV);
                float2 rampGrayNightUV = float2(rampGrayU, 1.0 - nightRampV);

                // 暗面 Ramp: U 固定在最暗端（始终使用暗色）
                float rampDarkU = rampClampMin;
                float2 rampDarkDayUV   = float2(rampDarkU, 1.0 - dayRampV);
                float2 rampDarkNightUV = float2(rampDarkU, 1.0 - nightRampV);

                // 根据光源 Y 分量在日夜 Ramp 之间插值
                float  isDay         = (L.y + 1.0) / 2.0;
                float3 rampGrayColor = lerp(
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampGrayNightUV).rgb,
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampGrayDayUV).rgb,
                    isDay);
                float3 rampDarkColor = lerp(
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDarkNightUV).rgb,
                    SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDarkDayUV).rgb,
                    isDay);

                // ---- 3d. 阴影组装 ----
                // 灰影 = 亮面 Ramp 色 × ShadowColor（受光面的暗色调）
                // 黑影 = 暗面 Ramp 色 × ShadowColor（背光面的暗色调）
                float3 grayShadowColor = baseColor * rampGrayColor * _ShadowColor.rgb;
                float3 darkShadowColor = baseColor * rampDarkColor * _ShadowColor.rgb;

                // lambertStep 决定亮/暗面分界
                float3 diffuse = lerp(grayShadowColor, baseColor, lambertStep);
                // ILM.g 控制阴影软硬度：g 越大越接近亮面
                diffuse = lerp(darkShadowColor, diffuse, saturate(ilm.g * 2.0));
                diffuse = lerp(diffuse,       baseColor, saturate(ilm.g - 0.5) * 2.0);

                // ====================================================
                // 4. 高光计算（Blinn-Phong）
                //   非金属高光 (nonMetallicSpec):
                //     只有高光强度超过 ILM.b 阈值的区域才产生高光（卡通高光切边）
                //     受 ILM.r（金属度）和 _KsNonMetallic 控制强度
                //   金属高光 (metallicSpec):
                //     连续的 Blinn-Phong 高光，受 ILM.b 和 _KsMetallic 控制
                //     乘 (lambertStep*0.8+0.2) 让暗面也有一点金属高光
                // ====================================================
                float blinnPhong = step(0.0, NoL) * pow(max(0.0, NoH), _SpecExpon);

                // 非金属：高光在亮面产生硬切（卡通风格）
                float3 nonMetallicSpec = step(1.0 - blinnPhong, ilm.b) * ilm.r
                                         * _KsNonMetallic;
                // 金属：连续高光，暗面也残留 20%
                float3 metallicSpec = blinnPhong * ilm.b * (lambertStep * 0.8 + 0.2)
                                      * baseColor * _KsMetallic;

                // ILM.r > 0.95 视为金属区域
                float isMetal = step(0.95, ilm.r);
                float3 specular = lerp(nonMetallicSpec, metallicSpec, isMetal);

                // ====================================================
                // 5. 金属反射
                //   用 MatCap 方式采样 MetalTex，仅在金属区域叠加
                //   MetalTex → universals/Avatar_Tex_MetalMap.png
                // ====================================================
                float3 metalRefl = SAMPLE_TEXTURE2D(_MetalTex, sampler_MetalTex, matcapUV).r
                                   * baseColor;
                float3 metallic = lerp(0.0, metalRefl, isMetal);

                // ====================================================
                // 6. 合成
                // ====================================================
                float3 albedo = diffuse + specular + metallic;

                // ---- 边缘光（深度差 + 菲涅尔）----
                float2 screenUV     = input.positionNDC.xy;
                float  rawDepth     = SampleSceneDepth(screenUV);
                float  linearDepth  = LinearEyeDepth(rawDepth, _ZBufferParams);
                float  rimOffset    = _RimOffset / _ScreenParams.x / max(1.0, pow(linearDepth, 2.0));
                float2 screenOffset = float2(lerp(-1.0, 1.0, step(0.0, normalVS.x)) * rimOffset, 0.0);
                float  offsetDepth  = SampleSceneDepth(screenUV + screenOffset);
                float  offsetLinear = LinearEyeDepth(offsetDepth, _ZBufferParams);
                float  rim          = saturate(offsetLinear - linearDepth);
                rim = step(_RimThreshold, rim) * clamp(rim * _RimStrength, 0.0, _RimMax);
                float fresnel  = 1.0 - saturate(NoV);
                fresnel = pow(fresnel, _RimFresnelPower);
                fresnel = fresnel * _RimFresnelClamp + (1.0 - _RimFresnelClamp);
                albedo = 1.0 - (1.0 - rim * fresnel) * (1.0 - albedo);

                // Alpha: 基础 Alpha × 各贴图 Alpha 通道
                // _DoubleSided 允许背面强制可见
                float alpha = _Alpha * baseTex.a * toonTex.a * sphereTex.a;
                alpha = saturate(min(max(isFacing, _DoubleSided), alpha));

                float4 col = float4(albedo, alpha);
                clip(col.a - 0.5); // Alpha < 0.5 时丢弃片元

                // 雾效混合
                col.rgb = MixFog(col.rgb, input.fogCoord);

                return col;
            }
            ENDHLSL
        }

        // ================================================================
        // Pass 3: DrawOutline — 背面膨胀描边（ILM.a 多色）
        //
        // Cull Front 只渲染背面，顶点沿法线外扩 _OutlineOffset。
        // 片元着色器采样 ILM.a 从 5 个 _OutlineMapColor 中选色，
        // 实现不同材质类型使用不同描边颜色（皮肤/衣服/头发区分）。
        // ================================================================
        Pass
        {
            Name "DrawOutline"
            Tags
            {
                "RenderPipeline" = "UniversalPipeline"
                "RenderType"     = "Opaque"
            }

            // 只渲染背面 → 膨胀后在轮廓处溢出形成描边
            Cull Front

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex  : POSITION;
                float2 uv      : TEXCOORD0;
                half3  normal  : NORMAL;
                half4  tangent : TANGENT;
                half4  color   : COLOR0;
                float4 texcoord2 : TEXCOORD2;   // 平滑法线（UV3）
            };

            struct v2f
            {
                float2 uv         : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float  fogCoord   : TEXCOORD1;
            };

            // 使用 sampler2D 旧语法避免与主 Pass 的 TEXTURE2D/SAMPLER 冲突
            CBUFFER_START(UnityPerMaterial)
                sampler2D _BaseTex;
                float4    _BaseTex_ST;
                sampler2D _ILM;
                float4    _OutlineMapColor0;
                float4    _OutlineMapColor1;
                float4    _OutlineMapColor2;
                float4    _OutlineMapColor3;
                float4    _OutlineMapColor4;
                float     _OutlineOffset;
            CBUFFER_END

            v2f vert(appdata v)
            {
                v2f o;

                // 沿法线外扩顶点（备选：v.tangent.xyz 用于头发）
                VertexPositionInputs vertexInput = GetVertexPositionInputs(
                    v.vertex.xyz + v.texcoord2.xyz * _OutlineOffset);

                o.uv         = TRANSFORM_TEX(v.uv, _BaseTex);
                o.positionCS = vertexInput.positionCS;
                o.fogCoord   = ComputeFogFactor(vertexInput.positionCS.z);

                return o;
            }

            float4 frag(v2f i, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                // 采样 ILM A 通道 → 材质类型枚举值
                float4 ilm     = tex2D(_ILM, i.uv);
                float  matEnum0 = 0.0;
                float  matEnum1 = 0.3;
                float  matEnum2 = 0.5;
                float  matEnum3 = 0.7;
                float  matEnum4 = 1.0;

                // ILM.a → 选择描边色的 Alpha（用于 clip 薄面遮罩）
                float4 color = lerp(_OutlineMapColor4, _OutlineMapColor3,
                                    step(ilm.a, (matEnum3 + matEnum4) / 2));
                color = lerp(color, _OutlineMapColor2,
                             step(ilm.a, (matEnum2 + matEnum3) / 2));
                color = lerp(color, _OutlineMapColor1,
                             step(ilm.a, (matEnum1 + matEnum2) / 2));
                color = lerp(color, _OutlineMapColor0,
                             step(ilm.a, (matEnum0 + matEnum1) / 2));

                // Alpha=0 → 丢弃像素（薄面/透明区域）
                clip(color.a - 0.01);

                // 描边颜色 = BaseTex 漫反射色 × 压暗系数
                // 皮肤区域自动偏暖棕，衣服自动偏深黑，不需要手动调色
                float4 baseTex = tex2D(_BaseTex, i.uv);
                float3 outlineRgb = baseTex.rgb * 0.25;

                float4 col = float4(outlineRgb, 1);
                col.rgb = MixFog(col.rgb, i.fogCoord);
                return col;
            }
            ENDHLSL
        }
    }
}
