Shader "Custom/EndfieldHybrid"
{
    Properties
    {
        _BaseTex ("Base Tex (_D)", 2D) = "white" {}
        _NormalTex ("Normal Tex (_N/_HN)", 2D) = "bump" {}
        _ParamTex ("Param Tex (_P)", 2D) = "white" {}
        _StyleTex ("Style Tex (_ST)", 2D) = "white" {}
        _RampTex ("Diffuse Ramp (_RD)", 2D) = "white" {}
        _SpecRampTex ("Spec Ramp (_RS)", 2D) = "white" {}
        _LutTex ("Color LUT", 2D) = "white" {}
        _MatCapTex ("MatCap", 2D) = "black" {}
        _MaskTex ("Mask", 2D) = "white" {}
        _FaceSDFTex ("Face SDF", 2D) = "black" {}
        _HighlightMaskTex ("Highlight Mask", 2D) = "black" {}
        _HairSpecTex ("Hair Spec Style", 2D) = "black" {}
        _EmissionTex ("Emission Tex", 2D) = "black" {}
        _FlowTex ("Flow Mask", 2D) = "black" {}

        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _ShadowColor ("Shadow Color", Color) = (0.78, 0.72, 0.68, 1)
        _RampBlend ("Ramp Tone Blend", Range(0, 1)) = 0.55
        _RampThreshold ("Ramp Threshold", Range(0, 1)) = 0.45
        _RampFeather ("Ramp Feather", Range(0.001, 0.5)) = 0.08
        _StyleRampStrength ("Style Ramp Strength", Range(0, 1)) = 0
        _RealtimeShadowStrength ("Realtime Shadow Strength", Range(0, 1)) = 0.65
        _ShadowFloor ("Shadow Floor", Range(0, 1)) = 0.28
        _LutStrength ("LUT Strength", Range(0, 1)) = 0.35
        _LutRow ("LUT Row", Range(0, 1)) = 0.5

        _NormalStrength ("Normal Strength", Range(0, 1)) = 0
        _MetallicScale ("Metallic Scale", Range(0, 1)) = 0.25
        _SmoothnessMin ("Smoothness Min", Range(0, 1)) = 0.18
        _SmoothnessMax ("Smoothness Max", Range(0, 1)) = 0.75
        _SmoothnessScale ("Smoothness Scale", Range(0, 2)) = 0.8
        _OcclusionStrength ("Occlusion Strength", Range(0, 1)) = 0.2
        _SpecRampStrength ("Spec Ramp Strength", Range(0, 2)) = 0.25
        _MatCapStrength ("MatCap Strength", Range(0, 2)) = 0.15
        _HighlightStrength ("Highlight Strength", Range(0, 2)) = 0
        _SDFShadowStrength ("SDF Shadow Strength", Range(0, 1)) = 0
        _SDFDirectionalRG ("SDF Directional RG", Range(0, 1)) = 1
        _SDFChannel ("SDF Channel 0=R 1=G 2=B 3=A", Range(0, 3)) = 0
        _SDFThreshold ("SDF Threshold", Range(0, 1)) = 0.48
        _SDFSoftness ("SDF Softness", Range(0.001, 0.5)) = 0.08
        _SDFBackFade ("SDF Back Fade", Range(0.001, 0.5)) = 0.12
        _SDFShadowColor ("SDF Shadow Color", Color) = (0.95, 0.72, 0.64, 1)
        _FaceForwardOS ("Face Forward OS", Vector) = (0, 0, 1, 0)
        _FaceRightOS ("Face Right OS", Vector) = (1, 0, 0, 0)
        _HairAnisoStrength ("Hair Aniso Strength", Range(0, 2)) = 0
        _HairAnisoPower ("Hair Aniso Power", Range(1, 256)) = 80
        _HairSpecShift ("Hair Spec Shift", Range(-1, 1)) = 0
        _EmissionColor ("Emission Color", Color) = (1, 1, 1, 1)
        _EmissionStrength ("Emission Strength", Range(0, 5)) = 0
        _DebugMode ("Debug Mode", Range(0, 9)) = 0
        _DebugExposure ("Debug Exposure", Range(0, 8)) = 1

        _RimColor ("Rim Color", Color) = (1, 1, 1, 1)
        _RimPower ("Rim Power", Range(0.1, 10)) = 4
        _RimIntensity ("Rim Intensity", Range(0, 2)) = 0.18

        _Alpha ("Alpha", Range(0, 1)) = 1
        _AlphaClip ("Alpha Clip", Range(0, 1)) = 0.5
        _DoubleSided ("Double Sided", Range(0, 1)) = 0

        _OutlineColor ("Outline Color", Color) = (0.08, 0.07, 0.06, 1)
        _OutlineWidth ("Outline Width", Float) = 0.0015
        _OutlineAlpha ("Outline Alpha", Range(0, 1)) = 0
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
        }

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

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "UniversalForward" }

            Cull Off

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
                float fogCoord : TEXCOORD6;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseTex_ST;
                float4 _BaseColor, _ShadowColor;
                float _RampBlend, _RampThreshold, _RampFeather, _StyleRampStrength, _RealtimeShadowStrength, _ShadowFloor;
                float _LutStrength, _LutRow;
                float _NormalStrength;
                float _MetallicScale, _SmoothnessMin, _SmoothnessMax, _SmoothnessScale, _OcclusionStrength;
                float _SpecRampStrength, _MatCapStrength, _HighlightStrength;
                float _SDFShadowStrength, _SDFDirectionalRG, _SDFChannel, _SDFThreshold, _SDFSoftness, _SDFBackFade;
                float4 _SDFShadowColor, _FaceForwardOS, _FaceRightOS;
                float _HairAnisoStrength, _HairAnisoPower, _HairSpecShift;
                float4 _EmissionColor;
                float _EmissionStrength, _DebugMode, _DebugExposure;
                float4 _RimColor;
                float _RimPower, _RimIntensity;
                float _Alpha, _AlphaClip, _DoubleSided;
            CBUFFER_END

            TEXTURE2D(_BaseTex); SAMPLER(sampler_BaseTex);
            TEXTURE2D(_NormalTex); SAMPLER(sampler_NormalTex);
            TEXTURE2D(_ParamTex); SAMPLER(sampler_ParamTex);
            TEXTURE2D(_StyleTex); SAMPLER(sampler_StyleTex);
            TEXTURE2D(_RampTex); SAMPLER(sampler_RampTex);
            TEXTURE2D(_SpecRampTex); SAMPLER(sampler_SpecRampTex);
            TEXTURE2D(_LutTex); SAMPLER(sampler_LutTex);
            TEXTURE2D(_MatCapTex); SAMPLER(sampler_MatCapTex);
            TEXTURE2D(_MaskTex); SAMPLER(sampler_MaskTex);
            TEXTURE2D(_FaceSDFTex); SAMPLER(sampler_FaceSDFTex);
            TEXTURE2D(_HighlightMaskTex); SAMPLER(sampler_HighlightMaskTex);
            TEXTURE2D(_HairSpecTex); SAMPLER(sampler_HairSpecTex);
            TEXTURE2D(_EmissionTex); SAMPLER(sampler_EmissionTex);
            TEXTURE2D(_FlowTex); SAMPLER(sampler_FlowTex);

            Varyings vert(Attributes input)
            {
                Varyings output;
                VertexPositionInputs pos = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs norm = GetVertexNormalInputs(input.normalOS, input.tangentOS);

                output.positionCS = pos.positionCS;
                output.positionWS = pos.positionWS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseTex);
                output.normalWS = norm.normalWS;
                output.tangentWS = norm.tangentWS;
                output.bitangentWS = norm.bitangentWS;
                output.shadowCoord = TransformWorldToShadowCoord(pos.positionWS);
                output.fogCoord = ComputeFogFactor(pos.positionCS.z);
                return output;
            }

            float3 SampleLut(float3 color)
            {
                float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
                float3 lut = SAMPLE_TEXTURE2D(_LutTex, sampler_LutTex, float2(saturate(luma), _LutRow)).rgb;
                return lerp(color, color * lut, _LutStrength);
            }

            float SelectChannel(float4 value, float channel)
            {
                float result = value.r;
                result = lerp(result, value.g, step(0.5, channel) * (1.0 - step(1.5, channel)));
                result = lerp(result, value.b, step(1.5, channel) * (1.0 - step(2.5, channel)));
                result = lerp(result, value.a, step(2.5, channel));
                return result;
            }

            float ComputeFaceSDFShadow(float2 uv, float3 lightDirWS)
            {
                float3 forwardVec = normalize(TransformObjectToWorldDir(_FaceForwardOS.xyz));
                float3 rightVec = normalize(TransformObjectToWorldDir(_FaceRightOS.xyz));
                float3 upVec = cross(forwardVec, rightVec);
                float sqrUpLen = dot(upVec, upVec);
                float3 projectedUp = sqrUpLen > 1e-12 ? dot(lightDirWS, upVec) / sqrUpLen * upVec : float3(0, 0, 0);
                float3 lightHead = lightDirWS - projectedUp;
                float lightHeadLen = length(lightHead);

                if (lightHeadLen <= 1e-5)
                    return 0.0;

                float3 lightHeadDir = lightHead / lightHeadLen;
                float cosAngle = clamp(dot(lightHeadDir, rightVec), -1.0, 1.0);
                float angle01 = acos(cosAngle) / 3.1415926;
                float exposeRight = step(angle01, 0.5);

                float valueR = pow(saturate(1.0 - angle01 * 2.0), 3.0);
                float valueL = pow(saturate(angle01 * 2.0 - 1.0), 3.0);
                float mixValue = lerp(valueL, valueR, exposeRight);

                float4 sdfTex = SAMPLE_TEXTURE2D(_FaceSDFTex, sampler_FaceSDFTex, uv);
                float sdfRight = SelectChannel(sdfTex, _SDFChannel);
                float sdfLeft = SelectChannel(SAMPLE_TEXTURE2D(_FaceSDFTex, sampler_FaceSDFTex, float2(1.0 - uv.x, uv.y)), _SDFChannel);
                sdfRight = lerp(sdfRight, sdfTex.r, _SDFDirectionalRG);
                sdfLeft = lerp(sdfLeft, sdfTex.g, _SDFDirectionalRG);
                float mixSdf = lerp(sdfRight, sdfLeft, exposeRight);

                float thresholdBias = _SDFThreshold - 0.5;
                float sdfLit = smoothstep(mixValue - _SDFSoftness, mixValue + _SDFSoftness, mixSdf + thresholdBias);
                float frontFade = smoothstep(-_SDFBackFade, _SDFBackFade, dot(lightHeadDir, forwardVec));
                sdfLit = lerp(1.0, sdfLit, frontFade);
                return 1.0 - sdfLit;
            }

            float4 frag(Varyings input, bool isFacing : SV_IsFrontFace) : SV_Target
            {
                float4 baseTex = SAMPLE_TEXTURE2D(_BaseTex, sampler_BaseTex, input.uv) * _BaseColor;
                float4 paramTex = SAMPLE_TEXTURE2D(_ParamTex, sampler_ParamTex, input.uv);
                float4 styleTex = SAMPLE_TEXTURE2D(_StyleTex, sampler_StyleTex, input.uv);
                float4 maskTex = SAMPLE_TEXTURE2D(_MaskTex, sampler_MaskTex, input.uv);
                float4 highlightMask = SAMPLE_TEXTURE2D(_HighlightMaskTex, sampler_HighlightMaskTex, input.uv);
                float4 hairSpecStyle = SAMPLE_TEXTURE2D(_HairSpecTex, sampler_HairSpecTex, input.uv);
                float4 emissionTex = SAMPLE_TEXTURE2D(_EmissionTex, sampler_EmissionTex, input.uv);
                float4 flowTex = SAMPLE_TEXTURE2D(_FlowTex, sampler_FlowTex, input.uv);

                float alpha = baseTex.a * _Alpha;
                alpha = saturate(min(max(isFacing, _DoubleSided), alpha));
                clip(alpha - _AlphaClip);

                float3 normalTS = UnpackNormal(SAMPLE_TEXTURE2D(_NormalTex, sampler_NormalTex, input.uv));
                normalTS = normalize(lerp(float3(0, 0, 1), normalTS, _NormalStrength));
                float3x3 tbn = float3x3(normalize(input.tangentWS), normalize(input.bitangentWS), normalize(input.normalWS));
                float3 N = normalize(mul(normalTS, tbn));
                float3 V = SafeNormalize(GetWorldSpaceViewDir(input.positionWS));

                Light light = GetMainLight(input.shadowCoord);
                float3 L = normalize(light.direction);
                float3 H = normalize(L + V);
                float NoL = saturate(dot(N, L));
                float NoV = saturate(dot(N, V));
                float NoH = saturate(dot(N, H));
                float halfLambert = NoL * 0.5 + 0.5;

                InputData inputData = (InputData)0;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = N;
                inputData.viewDirectionWS = V;
                inputData.shadowCoord = input.shadowCoord;
                inputData.fogCoord = input.fogCoord;
                inputData.vertexLighting = half3(0, 0, 0);
                inputData.bakedGI = SampleSH(N);
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = half4(1, 1, 1, 1);

                SurfaceData surfaceData = (SurfaceData)0;
                surfaceData.albedo = baseTex.rgb;
                surfaceData.metallic = saturate(paramTex.r * _MetallicScale);
                surfaceData.smoothness = saturate(lerp(_SmoothnessMin, _SmoothnessMax, 1.0 - paramTex.g) * _SmoothnessScale);
                surfaceData.occlusion = lerp(1.0, saturate(paramTex.b), _OcclusionStrength);
                surfaceData.normalTS = normalTS;
                surfaceData.alpha = alpha;

                float3 pbrColor = UniversalFragmentPBR(inputData, surfaceData).rgb;

                float rampU = saturate(smoothstep(_RampThreshold - _RampFeather, _RampThreshold + _RampFeather, halfLambert));
                rampU = lerp(rampU, styleTex.r, _StyleRampStrength);
                float3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(rampU, 0.5)).rgb;
                float3 lutBase = SampleLut(baseTex.rgb);
                float3 rampTone = lutBase * rampColor * _ShadowColor.rgb;

                float sdfRawShadow = ComputeFaceSDFShadow(input.uv, L);
                float sdfShadow = sdfRawShadow;
                float3 sdfTone = lutBase * _SDFShadowColor.rgb;
                rampTone = lerp(rampTone, sdfTone, sdfShadow * _SDFShadowStrength);

                float realtimeShadow = (1.0 - saturate(light.shadowAttenuation)) * _RealtimeShadowStrength;
                float rampShadow = 1.0 - rampU;

                if (_DebugMode > 0.5)
                {
                    float4 sdfTex = SAMPLE_TEXTURE2D(_FaceSDFTex, sampler_FaceSDFTex, input.uv);
                    float sdfChannel = SelectChannel(sdfTex, _SDFChannel);
                    float3 debugColor = baseTex.rgb;
                    debugColor = lerp(debugColor, paramTex.rgb, step(1.5, _DebugMode) * (1.0 - step(2.5, _DebugMode)));
                    debugColor = lerp(debugColor, styleTex.rgb, step(2.5, _DebugMode) * (1.0 - step(3.5, _DebugMode)));
                    debugColor = lerp(debugColor, maskTex.rgb, step(3.5, _DebugMode) * (1.0 - step(4.5, _DebugMode)));
                    debugColor = lerp(debugColor, sdfTex.rgb, step(4.5, _DebugMode) * (1.0 - step(5.5, _DebugMode)));
                    debugColor = lerp(debugColor, sdfChannel.xxx, step(5.5, _DebugMode) * (1.0 - step(6.5, _DebugMode)));
                    debugColor = lerp(debugColor, sdfShadow.xxx, step(6.5, _DebugMode) * (1.0 - step(7.5, _DebugMode)));
                    debugColor = lerp(debugColor, realtimeShadow.xxx, step(7.5, _DebugMode) * (1.0 - step(8.5, _DebugMode)));
                    debugColor = lerp(debugColor, rampShadow.xxx, step(8.5, _DebugMode));
                    return float4(saturate(debugColor * _DebugExposure), alpha);
                }

                float stylizedShadowMask = saturate(max(max(realtimeShadow, rampShadow), sdfShadow * _SDFShadowStrength));
                float3 color = lerp(pbrColor, rampTone, stylizedShadowMask * _RampBlend);
                color = max(color, lutBase * _ShadowFloor * stylizedShadowMask);

                float2 specUV = float2(NoH, saturate(paramTex.a));
                float3 specRamp = SAMPLE_TEXTURE2D(_SpecRampTex, sampler_SpecRampTex, specUV).rgb;
                color += specRamp * maskTex.r * _SpecRampStrength * pow(NoH, 32.0) * saturate(NoL + 0.2);

                float3 T = normalize(input.tangentWS);
                float hairSinTH = sqrt(saturate(1.0 - dot(T, H) * dot(T, H)));
                float hairSpec = pow(saturate(hairSinTH + _HairSpecShift), _HairAnisoPower);
                float hairMask = saturate(hairSpecStyle.r + hairSpecStyle.g * 0.5 + maskTex.r * 0.25);
                color += hairSpec * hairMask * specRamp * baseTex.rgb * _HairAnisoStrength * saturate(NoL + 0.35);

                float3 normalVS = normalize(mul((float3x3)UNITY_MATRIX_V, N));
                float2 matcapUV = normalVS.xy * 0.5 + 0.5;
                float3 matcap = SAMPLE_TEXTURE2D(_MatCapTex, sampler_MatCapTex, matcapUV).rgb;
                color += matcap * _MatCapStrength * maskTex.g;

                float faceHighlight = saturate(highlightMask.r + highlightMask.g * 0.5);
                color += faceHighlight * _HighlightStrength * lerp(0.4, 1.0, NoL) * baseTex.rgb;

                float emissionMask = saturate(emissionTex.a + emissionTex.r + flowTex.r * 0.35);
                color += emissionTex.rgb * _EmissionColor.rgb * emissionMask * _EmissionStrength;

                float rim = pow(1.0 - NoV, _RimPower) * _RimIntensity;
                color += rim * _RimColor.rgb;
                color = MixFog(color, input.fogCoord);
                return float4(color, alpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }

            Cull Front
            ZWrite On

            HLSLPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float fogCoord : TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineWidth, _OutlineAlpha;
            CBUFFER_END

            Varyings vert(Attributes input)
            {
                Varyings output;
                float3 positionOS = input.positionOS.xyz + normalize(input.normalOS) * _OutlineWidth;
                output.positionCS = TransformObjectToHClip(positionOS);
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                return output;
            }

            float4 frag(Varyings input) : SV_Target
            {
                clip(_OutlineAlpha - 0.001);
                float3 color = MixFog(_OutlineColor.rgb, input.fogCoord);
                return float4(color, _OutlineColor.a * _OutlineAlpha);
            }
            ENDHLSL
        }
    }
}
