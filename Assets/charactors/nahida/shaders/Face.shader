Shader "Unlit/Face"
{
    Properties
    {
        // --- 颜色与光照 ---
        _AmbientColor ("Ambient Color", Color) = (0.667,0.667,0.667,1)
        _DiffuseColor ("Diffuse Color", Color) = (0.906,0.906,0.906,1)
        _ShadowColor ("Shadow Color", Color) = (0.737,0.737,0.737,1)

        // --- 主贴图与卡通贴图 ---
        _BaseTexFac ("Base Tex Fac", Range(0,1)) = 1
        [MainTexture] _BaseTex ("Base Tex", 2D) = "white" {}
        _ToonTexFac ("Toon Tex Fac", Range(0,1)) = 1
        _ToonTex ("Toon Tex", 2D) = "white" {}

        // --- 环绕反射 (MatCap) ---
        _SphereTexFac ("Sphere Tex Fac", Range(0,1)) = 0
        _SphereTex ("Sphere Tex", 2D) = "white" {}
        _SphereMulAdd ("Sphere Mul/Add", Range(0,1)) = 0

        _DoubleSided ("Double Sided", Range(0,1)) = 0
        _Alpha ("Alpha", Range(0,1)) = 1

        // --- PBR 与 遮罩 ---

        _SDF ("SDF", 2D) = "black" {}
        _ForwardVector ("Forward Vector", Vector) = (0, 0, 1, 0)
        _RightVector ("Right Vector", Vector) = (1, 0, 0, 0)

        
        // _MetalTex ("Metal Tex", 2D) = "black" {}
        // _SpecExpon ("Spec Exponent", Range(1, 128)) = 50
        // _KsNonMetallic ("Ks Non-Metallic", Range(0, 3)) = 1
        // _KsMetallic ("Ks Metallic", Range(0, 3)) = 1

        // --- 法线与 ILM (重要：控制卡通阴影) ---
        // _NormalMap ("Normal Map", 2D) = "bump" {}
        // _ILM ("ILM", 2D) = "black" {}

        // --- Ramp 渐变控制 ---
        _RampTex ("Ramp Tex", 2D) = "white" {}
        _RampRow ("Ramp Row", Range(1, 5)) = 5
        // _RampMapRow0 ("Ramp Map Row 0", Range(1,5)) = 1
        // _RampMapRow1 ("Ramp Map Row 1", Range(1,5)) = 4
        // _RampMapRow2 ("Ramp Map Row 2", Range(1,5)) = 3
        // _RampMapRow3 ("Ramp Map Row 3", Range(1,5)) = 5
        // _RampMapRow4 ("Ramp Map Row 4", Range(1,5)) = 2

        // --- 描边 ---
        _OutlineOffset ("Outline Offset", Float) = 0.000015
        // _OutlineColor ("Outline Color", Float) = (0, 0, 0, 0)
    }

    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" "RenderType" = "Opaque" "Queue" = "Geometry" }
        LOD 100

        // ------------------------------------------------------------------
        // Pass 1: ShadowCaster (让模型能投射阴影) - 对应截图 2
        // ------------------------------------------------------------------
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

        // ------------------------------------------------------------------
        // Pass 2: DepthNormals (用于屏幕空间特效，如描边/环境光遮蔽) - 对应截图 3
        // ------------------------------------------------------------------
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

        // ------------------------------------------------------------------
        // Pass 3: UniversalForward (主渲染通路) - 对应截图 4, 5, 6
        // ------------------------------------------------------------------
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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float4 color : COLOR0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 positionVS : TEXCOORD2;
                float4 positionCS : SV_POSITION;
                float3 positionNDC : TEXCOORD3;
                float3 normalWS : TEXCOORD4;
                float3 tangentWS : TEXCOORD5;
                float3 bitangentWS : TEXCOORD6;
                float fogCoord : TEXCOORD7;
                float4 shadowCoord : TEXCOORD8;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _AmbientColor, _DiffuseColor, _ShadowColor;
                float _BaseTexFac, _ToonTexFac, _SphereTexFac, _SphereMulAdd;
                float4 _BaseTex_ST;
                float _DoubleSided, _Alpha;
                float _RampRow;
                float _OutlineOffset;
                float3 _ForwardVector, _RightVector;
            CBUFFER_END

            // 纹理采样器定义
            TEXTURE2D(_BaseTex);    SAMPLER(sampler_BaseTex);
            TEXTURE2D(_RampTex);    SAMPLER(sampler_RampTex);
            //TEXTURE2D(_NormalMap);  SAMPLER(sampler_NormalMap);
            TEXTURE2D(_ToonTex);    SAMPLER(sampler_ToonTex);

            TEXTURE2D(_SphereTex);  SAMPLER(sampler_SphereTex);
            TEXTURE2D(_SDF);        SAMPLER(sampler_SDF);
            //TEXTURE2D(_ILM);        SAMPLER(sampler_ILM);
            //TEXTURE2D(_MetalTex);   SAMPLER(sampler_MetalTex);

            // ... 其他贴图在此声明

            v2f vert (appdata v)
            {
                v2f o;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseTex);
                o.positionWS = vertexInput.positionWS;
                o.positionVS = vertexInput.positionVS;
                o.positionCS = vertexInput.positionCS;
                o.positionNDC = vertexInput.positionNDC;

                VertexNormalInputs normalInput = GetVertexNormalInputs(v.normal, v.tangent);
                o.tangentWS = normalInput.tangentWS;
                o.bitangentWS = normalInput.bitangentWS;
                o.normalWS = normalInput.normalWS;

                o.fogCoord = ComputeFogFactor(o.positionCS.z);
                o.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);
                return o;
            }

            float4 frag (v2f i, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                Light light = GetMainLight(i.shadowCoord);
                
                // PBR
                // float NoL = dot(normalize(i.normalWS), normalize(light.direction));
                // float lambert = max(0, NoL);
                // float halfLambert = pow(lambert * 0.5 + 0.5, 2);

                // float4 baseTex = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, i.uv);
                
                // float3 albedo = baseTex.rgb * halfLambert;
                // float alpha = baseTex.a * _Alpha;

                // float4 col = float4(albedo, alpha);
                // clip(col.a - 0.5);

                // col.rgb = MixFog(col.rgb, i.fogCoord);

                // NPR
                //parama
                // float4 normalMap = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, i.uv);
                // float3 normalTS = float3(normalMap.ag * 2 - 1, 0);
                // normalTS.z = sqrt(1 - dot(normalTS.xy, normalTS.xy));

                float3 N = normalize(i.normalWS);
                float3 V = normalize(mul((float3x3)UNITY_MATRIX_I_V, i.positionVS * (-1)));
                float3 L = normalize(light.direction);
                // float3 H = normalize(V + L);

                // float NoL = dot(N, L);
                // float NoH = dot(N, H);
                float NoV = dot(N, V);

                float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, N));
                float2 matcapUV = normalVS.xy * 0.5 + 0.5;

                float4 baseTex = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, i.uv);
                float4 toonTex = SAMPLE_TEXTURE2D(_ToonTex, sampler_ToonTex, matcapUV);
                float4 sphereTex = SAMPLE_TEXTURE2D(_SphereTex, sampler_SphereTex, matcapUV);

                //basecolor
                float3 baseColor = _AmbientColor.rgb;
                baseColor = saturate(lerp(baseColor, baseColor+_DiffuseColor.rgb, 0.6));
                baseColor = lerp(baseColor, baseColor * baseTex.rgb, _BaseTexFac);
                baseColor = lerp(baseColor, baseColor * toonTex.rgb, _ToonTexFac);

                baseColor = lerp(lerp(baseColor, baseColor * sphereTex.rgb, _SphereTexFac), lerp(baseColor, baseColor + sphereTex.rgb, _SphereTexFac),_SphereMulAdd);

                float rampV = _RampRow / 10 - 0.05;
                float rampClampMin = 0.003;
                float2 rampDayUV = float2(rampClampMin, 1 - rampV);
                float2 rampNightUV = float2(rampClampMin, 1 - (rampV + 0.5));


                float isDay = (L.y + 1) / 2;
                float3 rampColor = lerp(SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampNightUV).rgb, SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDayUV).rgb, isDay);
                
                float3 forwardVec = _ForwardVector;
                float3 rightVec = _RightVector;

                float3 upVector = cross(forwardVec, rightVec);
                float sqrUpLen = dot(upVector, upVector);
                float3 LpU = sqrUpLen > 1e-12 ? dot(L, upVector) / sqrUpLen * upVector : 0;
                float3 LpHead = L - LpU;

                float sdf = 1; // default lit
                float LpHeadLen = length(LpHead);
                if (LpHeadLen > 1e-5)
                {
                    float3 LpHeadDir = LpHead / LpHeadLen;
                    float cosAngle = dot(LpHeadDir, normalize(rightVec));
                    cosAngle = clamp(cosAngle, -1.0, 1.0);
                    float value = acos(cosAngle) / 3.1415926;

                    float exposRight = step(value, 0.5);

                    float valueR = pow(saturate(1 - value * 2), 3);
                    float valueL = pow(saturate(value * 2 - 1), 3);

                    float mixValue = lerp(valueL, valueR, exposRight);

                    float sdfRembrandLeft  = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, float2(1 - i.uv.x, i.uv.y)).r;
                    float sdfRembrandRight = SAMPLE_TEXTURE2D(_SDF, sampler_SDF, i.uv).r;
                    float mixSdf = lerp(sdfRembrandRight, sdfRembrandLeft, exposRight);

                    float sdfRaw = step(mixValue, mixSdf);
                    sdf = lerp(1, sdfRaw, step(0, dot(LpHeadDir, normalize(forwardVec))));
                }
                
                

                return float4(sdf, sdf, sdf, 1);                
                // //Lightmap
                // float4 ilm = SAMPLE_TEXTURE2D(_ILM, sampler_ILM, i.uv);
                
                // float matEnum0 = 0.0;
                // float matEnum1 = 0.3;
                // float matEnum2 = 0.5;
                // float matEnum3 = 0.7;
                // float matEnum4 = 1.0;

                // float ramp0 = _RampMapRow0 / 10.0 - 0.05;
                // float ramp1 = _RampMapRow1 / 10.0 - 0.05;
                // float ramp2 = _RampMapRow2 / 10.0 - 0.05;
                // float ramp3 = _RampMapRow3 / 10.0 - 0.05;
                // float ramp4 = _RampMapRow4 / 10.0 - 0.05;

                // float dayRampV = lerp(ramp4, ramp3, step(ilm.a, (matEnum3 + matEnum4) / 2));
                // dayRampV = lerp(dayRampV, ramp2, step(ilm.a, (matEnum2 + matEnum3) / 2));
                // dayRampV = lerp(dayRampV, ramp1, step(ilm.a, (matEnum1 + matEnum2) / 2));
                // dayRampV = lerp(dayRampV, ramp0, step(ilm.a, (matEnum0 + matEnum1) / 2));
                
                // float nightRampV = dayRampV + 0.5;


                // float lambert = max(0, NoL);
                // float halfLambert = pow(lambert * 0.5 + 0.5, 2);
                // float lambertStep = smoothstep(0.423, 0.450, halfLambert);

                // float rampClampMin = 0.003;
                // float rampClampMax = 0.997;
                
                // //rampmap
                // float rampGrayU = clamp(smoothstep(0.2, 0.4, halfLambert), rampClampMin, rampClampMax);
                // float2 rampGrayDayUV = float2(rampGrayU, 1 - dayRampV);
                // float2 rampGrayNightUV = float2(rampGrayU, 1- nightRampV);


                // float rampDarkU = rampClampMin;
                // float2 rampDarkDayUV = float2(rampDarkU, 1 - dayRampV);
                // float2 rampDarkNightUV = float2(rampDarkU, 1 - nightRampV);

                // float isDay = (L.y + 1) / 2;
                // float3 rampGrayColor = lerp(SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampGrayNightUV).rgb, SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampGrayDayUV).rgb, isDay);
                // float3 rampDarkColor = lerp(SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDarkNightUV).rgb, SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, rampDarkDayUV).rgb, isDay);

                // float3 grayShadowColor = baseColor * rampGrayColor * _ShadowColor;
                // float3 darkShadowColor = baseColor * rampDarkColor * _ShadowColor;

                // float3 diffuse = lerp(grayShadowColor, baseColor, lambertStep);
                // diffuse = lerp(darkShadowColor, diffuse, saturate(ilm.g * 2));
                // diffuse = lerp(diffuse, baseColor, saturate(ilm.g - 0.5) * 2);

                // float blinnPhong = step(0, NoL) * pow(max(0, NoH), _SpecExpon);
                // float3 nonMetallicSpec = step(1.0 - blinnPhong, ilm.b) * ilm.r * _KsNonMetallic;
                // float3 metallicSpec = blinnPhong * ilm.b * (lambertStep * 0.8 + 0.2) * baseColor *  _KsMetallic;

                // float isMetal = step(0.95, ilm.r);

                // float3 specular = lerp(nonMetallicSpec, metallicSpec, isMetal);

                // float3 metallic = lerp(0, SAMPLE_TEXTURE2D(_MetalTex, sampler_MetalTex, matcapUV).r * baseColor, isMetal);

                // float3 albedo = diffuse + specular + metallic;
                // float alpha = _Alpha * baseTex.a * toonTex.a * sphereTex.a;
                // alpha = saturate(min(max(isFacing, _DoubleSided), alpha));

                // float4 col = float4(albedo, alpha);
                // clip(col.a - 0.5);

                // col.rgb = MixFog(col.rgb, i.fogCoord);
                // return col;
            }
            ENDHLSL
        }
    }
}