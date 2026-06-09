using UnityEditor;
using UnityEngine;

public static class ZhuangfyMaterialSetup
{
    private const string Root = "Assets/charactors/zhuangfy";
    private const string MatRoot = Root + "/Materials";
    private const string TexRoot = Root + "/textures";
    private const string OtherTexRoot = Root + "/other_tex";

    [MenuItem("Tools/Zhuangfy/Assign Endfield Hybrid Materials")]
    public static void AssignHybridMaterials()
    {
        var shader = Shader.Find("Custom/EndfieldHybrid");
        if (shader == null)
        {
            Debug.LogError("Custom/EndfieldHybrid not found. Let Unity import EndfieldHybrid.shader first.");
            return;
        }

        ApplyTextureImportSettings(false);
        ConfigureFace(shader);
        ConfigureEyes(shader);
        ConfigureHair(shader);
        ConfigureSkin(shader);
        ConfigureCloth(shader);
        ConfigureEmotion(shader);
        DisableOutlines();

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("Zhuangfy materials assigned to Custom/EndfieldHybrid.");
    }

    [MenuItem("Tools/Zhuangfy/Assign Base Color Check Materials")]
    public static void AssignBaseColorCheckMaterials()
    {
        var shader = Shader.Find("Custom/EndfieldHybrid");
        if (shader == null)
        {
            Debug.LogError("Custom/EndfieldHybrid not found. Let Unity import EndfieldHybrid.shader first.");
            return;
        }

        ConfigureFace(shader);
        ConfigureEyes(shader);
        ConfigureHair(shader);
        ConfigureSkin(shader);
        ConfigureCloth(shader);
        ConfigureEmotion(shader);

        for (var i = 0; i <= 12; i++)
        {
            var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/{i}.mat");
            if (mat == null) continue;
            mat.SetFloat("_RampBlend", 0.0f);
            mat.SetFloat("_StyleRampStrength", 0.0f);
            mat.SetFloat("_RealtimeShadowStrength", 0.0f);
            mat.SetFloat("_NormalStrength", 0.0f);
            mat.SetFloat("_MetallicScale", 0.0f);
            mat.SetFloat("_SpecRampStrength", 0.0f);
            mat.SetFloat("_MatCapStrength", 0.0f);
            mat.SetFloat("_HighlightStrength", 0.0f);
            mat.SetFloat("_SDFShadowStrength", 0.0f);
            mat.SetFloat("_HairAnisoStrength", 0.0f);
            mat.SetFloat("_EmissionStrength", 0.0f);
            mat.SetFloat("_LutStrength", 0.0f);
            mat.SetFloat("_RimIntensity", 0.0f);
            mat.SetFloat("_OutlineAlpha", 0.0f);
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();
        Debug.Log("Zhuangfy materials assigned to base color check mode.");
    }

    [MenuItem("Tools/Zhuangfy/Fix Texture Import Settings")]
    public static void FixTextureImportSettingsMenu() => ApplyTextureImportSettings(true);

    [MenuItem("Tools/Zhuangfy/Debug/Disable Outlines")]
    public static void DisableOutlinesMenu()
    {
        DisableOutlines();
        AssetDatabase.SaveAssets();
        Debug.Log("Zhuangfy outlines disabled.");
    }

    [MenuItem("Tools/Zhuangfy/Debug/Hybrid Debug Off")]
    public static void DisableHybridDebug() => SetHybridDebugMode(0);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Base Color")]
    public static void DebugFaceHybridBaseColor() => SetFaceHybridDebugMode(1);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Param P RGB")]
    public static void DebugFaceHybridParam() => SetFaceHybridDebugMode(2);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Style ST RGB")]
    public static void DebugFaceHybridStyle() => SetFaceHybridDebugMode(3);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Mask RGB")]
    public static void DebugFaceHybridMask() => SetFaceHybridDebugMode(4);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/SDF RGB")]
    public static void DebugFaceHybridSdfRgb() => SetFaceHybridDebugMode(5);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/SDF Selected Channel")]
    public static void DebugFaceHybridSdfChannel() => SetFaceHybridDebugMode(6);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Computed SDF Shadow")]
    public static void DebugFaceHybridComputedSdf() => SetFaceHybridDebugMode(7);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Realtime Shadow")]
    public static void DebugFaceHybridRealtimeShadow() => SetFaceHybridDebugMode(8);

    [MenuItem("Tools/Zhuangfy/Debug/Face Hybrid/Ramp Shadow")]
    public static void DebugFaceHybridRampShadow() => SetFaceHybridDebugMode(9);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/Base RGB")]
    public static void DebugFaceBaseRgb() => AssignFaceTextureDebug(TexRoot + "/T_actor_zhuangfy_face_01_D.png", 0, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/ST RGB")]
    public static void DebugFaceStyleRgb() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_01_ST.png", 0, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/CM Mask RGB")]
    public static void DebugFaceMaskRgb() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_01_cm_M.png", 0, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/Highlight Mask RGB")]
    public static void DebugFaceHighlightRgb() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_face_01_hl_M.png", 0, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/SDF RGB")]
    public static void DebugFaceSdfRgb() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_02_SDF.png", 0, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/SDF R")]
    public static void DebugFaceSdfR() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_02_SDF.png", 1, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/SDF G")]
    public static void DebugFaceSdfG() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_02_SDF.png", 2, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/SDF B")]
    public static void DebugFaceSdfB() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_02_SDF.png", 3, 1.0f);

    [MenuItem("Tools/Zhuangfy/Debug/Face Texture/SDF A")]
    public static void DebugFaceSdfA() => AssignFaceTextureDebug(OtherTexRoot + "/T_actor_common_female_face_02_SDF.png", 4, 4.0f);

    [MenuItem("Tools/Zhuangfy/Face SDF/Use Channel R")]
    public static void UseFaceSDFChannelR() => SetFaceSDFChannel(0);

    [MenuItem("Tools/Zhuangfy/Face SDF/Use Channel G")]
    public static void UseFaceSDFChannelG() => SetFaceSDFChannel(1);

    [MenuItem("Tools/Zhuangfy/Face SDF/Use Channel B")]
    public static void UseFaceSDFChannelB() => SetFaceSDFChannel(2);

    [MenuItem("Tools/Zhuangfy/Face SDF/Use Channel A")]
    public static void UseFaceSDFChannelA() => SetFaceSDFChannel(3);

    [MenuItem("Tools/Zhuangfy/Face SDF/Swap Directional RG Off")]
    public static void SwapFaceSDFDirectionalRGOff() => SetFaceSDFSwapRG(0.0f);

    [MenuItem("Tools/Zhuangfy/Face SDF/Swap Directional RG On")]
    public static void SwapFaceSDFDirectionalRGOn() => SetFaceSDFSwapRG(1.0f);

    [MenuItem("Tools/Zhuangfy/Face SDF/Direction Default +Z/+X")]
    public static void UseDefaultFaceDirection() => SetFaceDirection(new Vector4(0, 0, 1, 0), new Vector4(1, 0, 0, 0));

    [MenuItem("Tools/Zhuangfy/Face SDF/Direction Flip Forward -Z/+X")]
    public static void FlipFaceForward() => SetFaceDirection(new Vector4(0, 0, -1, 0), new Vector4(1, 0, 0, 0));

    [MenuItem("Tools/Zhuangfy/Face SDF/Direction Flip Right +Z/-X")]
    public static void FlipFaceRight() => SetFaceDirection(new Vector4(0, 0, 1, 0), new Vector4(-1, 0, 0, 0));

    [MenuItem("Tools/Zhuangfy/Face SDF/Direction Flip Both -Z/-X")]
    public static void FlipFaceBoth() => SetFaceDirection(new Vector4(0, 0, -1, 0), new Vector4(-1, 0, 0, 0));

    private static void ConfigureFace(Shader shader)
    {
        foreach (var index in new[] { 0, 3, 5, 6 })
        {
            var mat = Mat(index, shader);
            if (mat == null) continue;
            CommonFace(mat);
            mat.SetFloat("_RampBlend", 0.42f);
            mat.SetFloat("_StyleRampStrength", 0.0f);
            mat.SetFloat("_RealtimeShadowStrength", 0.0f);
            mat.SetFloat("_LutStrength", 0.35f);
            mat.SetFloat("_NormalStrength", 0.0f);
            mat.SetFloat("_MetallicScale", 0.0f);
            mat.SetFloat("_SmoothnessScale", 0.45f);
            mat.SetFloat("_ShadowFloor", 0.42f);
            mat.SetFloat("_SDFShadowStrength", index == 0 ? 0.85f : 0.0f);
            mat.SetFloat("_SDFDirectionalRG", 1.0f);
            mat.SetFloat("_SDFSwapRG", 0.0f);
            mat.SetFloat("_SDFChannel", 0.0f);
            mat.SetFloat("_SDFThreshold", 0.5f);
            mat.SetFloat("_SDFSoftness", 0.025f);
            mat.SetFloat("_SDFBackFade", 0.16f);
            mat.SetVector("_FaceForwardOS", new Vector4(0, 0, 1, 0));
            mat.SetVector("_FaceRightOS", new Vector4(1, 0, 0, 0));
            mat.SetFloat("_HighlightStrength", 0.12f);
            mat.SetFloat("_DebugMode", 0.0f);
            mat.SetFloat("_DebugExposure", 1.0f);
            mat.SetFloat("_OutlineWidth", 0.0008f);
        }

        var eyeShadow = Mat(4, shader);
        if (eyeShadow != null)
        {
            CommonFace(eyeShadow);
            Tex(eyeShadow, "_MaskTex", OtherTexRoot + "/T_actor_common_eyeshadow_01_M.png");
            eyeShadow.SetFloat("_RampBlend", 0.2f);
            eyeShadow.SetFloat("_StyleRampStrength", 0.0f);
            eyeShadow.SetFloat("_RealtimeShadowStrength", 0.0f);
            eyeShadow.SetFloat("_Alpha", 0.35f);
            eyeShadow.SetFloat("_AlphaClip", 0.02f);
            eyeShadow.SetFloat("_DebugMode", 0.0f);
            eyeShadow.SetFloat("_OutlineAlpha", 0.0f);
        }
    }

    private static void ConfigureEyes(Shader shader)
    {
        foreach (var index in new[] { 1, 2 })
        {
            var mat = Mat(index, shader);
            if (mat == null) continue;
            Tex(mat, "_BaseTex", TexRoot + "/T_actor_zhuangfy_iris_01_D.png");
            Tex(mat, "_RampTex", OtherTexRoot + "/T_actor_common_face_01_RD.png");
            Tex(mat, "_SpecRampTex", OtherTexRoot + "/T_actor_common_face_01_RD.png");
            Tex(mat, "_LutTex", OtherTexRoot + "/T_actor_common_femaleskincolor01_lut_D.png");
            Tex(mat, "_MatCapTex", OtherTexRoot + "/T_actor_common_matcap_10_D.png");
            mat.SetFloat("_RampBlend", 0.2f);
            mat.SetFloat("_StyleRampStrength", 0.0f);
            mat.SetFloat("_RealtimeShadowStrength", 0.15f);
            mat.SetFloat("_NormalStrength", 0.0f);
            mat.SetFloat("_SmoothnessScale", 1.2f);
            mat.SetFloat("_SpecRampStrength", 0.55f);
            mat.SetFloat("_MatCapStrength", 0.25f);
            mat.SetFloat("_HighlightStrength", 0.45f);
            mat.SetFloat("_DebugMode", 0.0f);
            mat.SetFloat("_OutlineAlpha", 0.0f);
        }
    }

    private static void ConfigureHair(Shader shader)
    {
        var hair = Mat(7, shader);
        if (hair != null)
        {
            Tex(hair, "_BaseTex", TexRoot + "/T_actor_zhuangfy_hair_01_D.png");
            Tex(hair, "_NormalTex", OtherTexRoot + "/T_actor_zhuangfy_hair_01_HN.png");
            Tex(hair, "_ParamTex", OtherTexRoot + "/T_actor_zhuangfy_hair_01_P.png");
            Tex(hair, "_StyleTex", OtherTexRoot + "/T_actor_zhuangfy_hair_01_ST.png");
            Tex(hair, "_RampTex", OtherTexRoot + "/T_actor_common_hair_01_RD.png");
            Tex(hair, "_SpecRampTex", OtherTexRoot + "/T_actor_common_hair_09_RS.png");
            Tex(hair, "_LutTex", OtherTexRoot + "/T_actor_common_hair_01_RD.png");
            Tex(hair, "_MatCapTex", OtherTexRoot + "/T_actor_common_matcap_10_D.png");
            Tex(hair, "_MaskTex", OtherTexRoot + "/T_actor_common_hairline_03_M.png");
            Tex(hair, "_HairSpecTex", OtherTexRoot + "/T_actor_common_hairst_01_ST.png");
            hair.SetFloat("_RampBlend", 0.38f);
            hair.SetFloat("_StyleRampStrength", 0.0f);
            hair.SetFloat("_RealtimeShadowStrength", 0.45f);
            hair.SetFloat("_NormalStrength", 0.0f);
            hair.SetFloat("_LutStrength", 0.08f);
            hair.SetFloat("_SpecRampStrength", 0.18f);
            hair.SetFloat("_MatCapStrength", 0.05f);
            hair.SetFloat("_HairAnisoStrength", 0.75f);
            hair.SetFloat("_HairAnisoPower", 96.0f);
            hair.SetFloat("_HairSpecShift", -0.08f);
            hair.SetFloat("_SmoothnessScale", 0.85f);
            hair.SetFloat("_ShadowFloor", 0.45f);
            hair.SetColor("_ShadowColor", new Color(0.62f, 0.68f, 0.78f, 1));
            hair.SetFloat("_DebugMode", 0.0f);
            hair.SetFloat("_OutlineWidth", 0.0012f);
        }

        var hairShadow = Mat(8, shader);
        if (hairShadow != null)
        {
            Tex(hairShadow, "_BaseTex", TexRoot + "/T_actor_zhuangfy_hair_01_D.png");
            Tex(hairShadow, "_MaskTex", OtherTexRoot + "/T_actor_common_hairshadow_01_M.png");
            Tex(hairShadow, "_RampTex", OtherTexRoot + "/T_actor_common_hair_01_RD.png");
            hairShadow.SetFloat("_RampBlend", 0.35f);
            hairShadow.SetFloat("_StyleRampStrength", 0.0f);
            hairShadow.SetFloat("_RealtimeShadowStrength", 0.0f);
            hairShadow.SetFloat("_NormalStrength", 0.0f);
            hairShadow.SetFloat("_Alpha", 0.28f);
            hairShadow.SetFloat("_AlphaClip", 0.02f);
            hairShadow.SetFloat("_DebugMode", 0.0f);
            hairShadow.SetFloat("_OutlineAlpha", 0.0f);
        }
    }

    private static void ConfigureSkin(Shader shader)
    {
        var skin = Mat(9, shader);
        if (skin == null) return;
        Tex(skin, "_BaseTex", TexRoot + "/T_actor_zhaungfy_body_01_D.png");
        Tex(skin, "_RampTex", OtherTexRoot + "/T_actor_common_body_01_RD.png");
        Tex(skin, "_LutTex", OtherTexRoot + "/T_actor_common_femaleskincolor01_lut_D.png");
        Tex(skin, "_MatCapTex", OtherTexRoot + "/T_actor_common_matcap_10_D.png");
        skin.SetFloat("_RampBlend", 0.72f);
        skin.SetFloat("_StyleRampStrength", 0.0f);
        skin.SetFloat("_RealtimeShadowStrength", 0.28f);
        skin.SetFloat("_NormalStrength", 0.0f);
        skin.SetFloat("_LutStrength", 0.4f);
        skin.SetFloat("_MetallicScale", 0.0f);
        skin.SetFloat("_SmoothnessScale", 0.45f);
        skin.SetColor("_ShadowColor", new Color(0.9f, 0.72f, 0.62f, 1));
        skin.SetFloat("_DebugMode", 0.0f);
        skin.SetFloat("_OutlineWidth", 0.0007f);
    }

    private static void ConfigureCloth(Shader shader)
    {
        foreach (var index in new[] { 10, 11 })
        {
            var mat = Mat(index, shader);
            if (mat == null) continue;
            Tex(mat, "_BaseTex", TexRoot + "/T_actor_zhuangfy_cloth_01_D.png");
            Tex(mat, "_NormalTex", OtherTexRoot + "/T_actor_zhuangfy_cloth_01_N.png");
            Tex(mat, "_ParamTex", OtherTexRoot + "/T_actor_zhuangfy_cloth_01_P.png");
            Tex(mat, "_StyleTex", OtherTexRoot + "/T_actor_zhuangfy_cloth_01_ST.png");
            Tex(mat, "_RampTex", OtherTexRoot + "/T_actor_common_cloth_04_RD.png");
            Tex(mat, "_SpecRampTex", OtherTexRoot + "/T_actor_common_cloth_04_RS.png");
            Tex(mat, "_LutTex", OtherTexRoot + "/T_actor_common_cloth_lut_01_D.png");
            Tex(mat, "_MatCapTex", OtherTexRoot + "/T_actor_common_matcap_10_D.png");
            Tex(mat, "_MaskTex", OtherTexRoot + "/T_actor_zhuangfy_cloth_01_E.png");
            Tex(mat, "_EmissionTex", OtherTexRoot + "/T_actor_zhuangfy_cloth_01_E.png");
            Tex(mat, "_FlowTex", OtherTexRoot + "/T_fx_flow_517_M.png");
            mat.SetFloat("_RampBlend", 0.52f);
            mat.SetFloat("_StyleRampStrength", 0.15f);
            mat.SetFloat("_RealtimeShadowStrength", 0.75f);
            mat.SetFloat("_NormalStrength", 1.0f);
            mat.SetFloat("_LutStrength", 0.35f);
            mat.SetFloat("_MetallicScale", 0.45f);
            mat.SetFloat("_SmoothnessScale", 0.85f);
            mat.SetFloat("_SpecRampStrength", 0.35f);
            mat.SetFloat("_MatCapStrength", 0.12f);
            mat.SetFloat("_EmissionStrength", 0.12f);
            mat.SetColor("_ShadowColor", new Color(0.72f, 0.72f, 0.78f, 1));
            mat.SetFloat("_DebugMode", 0.0f);
            mat.SetFloat("_OutlineWidth", 0.0014f);
        }

        var alpha = Mat(11, shader);
        if (alpha != null)
        {
            alpha.SetFloat("_AlphaClip", 0.18f);
            alpha.SetFloat("_OutlineAlpha", 0.25f);
        }
    }

    private static void ConfigureEmotion(Shader shader)
    {
        var mat = Mat(12, shader);
        if (mat == null) return;
        Tex(mat, "_BaseTex", TexRoot + "/T_actor_common_female_emotion_atlas_01_D.png");
        Tex(mat, "_RampTex", OtherTexRoot + "/T_actor_common_face_01_RD.png");
        mat.SetFloat("_RampBlend", 0.45f);
        mat.SetFloat("_StyleRampStrength", 0.0f);
        mat.SetFloat("_RealtimeShadowStrength", 0.0f);
        mat.SetFloat("_NormalStrength", 0.0f);
        mat.SetFloat("_Alpha", 0.65f);
        mat.SetFloat("_AlphaClip", 0.02f);
        mat.SetFloat("_DebugMode", 0.0f);
        mat.SetFloat("_OutlineAlpha", 0.0f);
    }

    private static void CommonFace(Material mat)
    {
        Tex(mat, "_BaseTex", TexRoot + "/T_actor_zhuangfy_face_01_D.png");
        Tex(mat, "_StyleTex", OtherTexRoot + "/T_actor_common_female_face_01_ST.png");
        Tex(mat, "_RampTex", OtherTexRoot + "/T_actor_common_face_01_RD.png");
        Tex(mat, "_SpecRampTex", OtherTexRoot + "/T_actor_common_face_01_RD.png");
        Tex(mat, "_LutTex", OtherTexRoot + "/T_actor_common_femaleskincolor01_lut_D.png");
        Tex(mat, "_MatCapTex", OtherTexRoot + "/T_actor_common_matcap_10_D.png");
        Tex(mat, "_MaskTex", OtherTexRoot + "/T_actor_common_female_face_01_cm_M.png");
        Tex(mat, "_FaceSDFTex", OtherTexRoot + "/T_actor_common_female_face_02_SDF.png");
        Tex(mat, "_HighlightMaskTex", OtherTexRoot + "/T_actor_common_face_01_hl_M.png");
        mat.SetColor("_ShadowColor", new Color(0.92f, 0.76f, 0.68f, 1));
        mat.SetColor("_SDFShadowColor", new Color(0.95f, 0.70f, 0.62f, 1));
    }

    private static void SetFaceSDFChannel(float channel)
    {
        foreach (var mat in FaceMaterials())
        {
            if (mat == null) continue;
            mat.SetFloat("_SDFDirectionalRG", 0.0f);
            mat.SetFloat("_SDFSwapRG", 0.0f);
            mat.SetFloat("_SDFChannel", channel);
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy face SDF channel set to {channel}.");
    }

    [MenuItem("Tools/Zhuangfy/Face SDF/Use Directional RG")]
    public static void UseFaceSDFDirectionalRG()
    {
        foreach (var mat in FaceMaterials())
        {
            if (mat == null) continue;
            mat.SetFloat("_SDFDirectionalRG", 1.0f);
            mat.SetFloat("_SDFSwapRG", 0.0f);
        }

        AssetDatabase.SaveAssets();
        Debug.Log("Zhuangfy face SDF set to directional RG mode.");
    }

    private static void SetFaceSDFSwapRG(float value)
    {
        foreach (var mat in FaceMaterials())
        {
            if (mat == null) continue;
            mat.SetFloat("_SDFSwapRG", value);
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy face SDF directional RG swap set to {value}.");
    }

    private static void SetFaceDirection(Vector4 forwardOS, Vector4 rightOS)
    {
        foreach (var mat in FaceMaterials())
        {
            if (mat == null) continue;
            mat.SetVector("_FaceForwardOS", forwardOS);
            mat.SetVector("_FaceRightOS", rightOS);
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy face SDF direction set. Forward={forwardOS}, Right={rightOS}");
    }

    private static Material[] FaceMaterials()
    {
        var indices = new[] { 0, 3, 5, 6 };
        var materials = new Material[indices.Length];
        for (var i = 0; i < indices.Length; i++)
            materials[i] = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/{indices[i]}.mat");
        return materials;
    }

    private static void SetHybridDebugMode(float mode)
    {
        for (var i = 0; i <= 12; i++)
        {
            var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/{i}.mat");
            if (mat == null || !mat.HasProperty("_DebugMode")) continue;
            mat.SetFloat("_DebugMode", mode);
            mat.SetFloat("_DebugExposure", 1.0f);
        }

        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy hybrid debug mode set to {mode}.");
    }

    private static void SetFaceHybridDebugMode(float mode)
    {
        SetHybridDebugMode(0);
        var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/0.mat");
        if (mat == null)
        {
            Debug.LogWarning($"Missing face material: {MatRoot}/0.mat");
            return;
        }

        if (!mat.HasProperty("_DebugMode"))
        {
            Debug.LogWarning("Face material is not using Custom/EndfieldHybrid. Run Assign Endfield Hybrid Materials first.");
            return;
        }

        mat.SetFloat("_DebugMode", mode);
        mat.SetFloat("_DebugExposure", 1.0f);
        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy face hybrid debug mode set to {mode}.");
    }

    private static void AssignFaceTextureDebug(string texturePath, float channel, float exposure)
    {
        var shader = Shader.Find("Custom/EndfieldDebug");
        if (shader == null)
        {
            Debug.LogError("Custom/EndfieldDebug not found. Let Unity import EndfieldDebug.shader first.");
            return;
        }

        var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/0.mat");
        if (mat == null)
        {
            Debug.LogWarning($"Missing face material: {MatRoot}/0.mat");
            return;
        }

        var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(texturePath);
        if (tex == null)
        {
            Debug.LogWarning($"Missing debug texture: {texturePath}");
            return;
        }

        mat.shader = shader;
        mat.SetTexture("_MainTex", tex);
        mat.SetFloat("_Channel", channel);
        mat.SetFloat("_Exposure", exposure);
        AssetDatabase.SaveAssets();
        Debug.Log($"Zhuangfy face texture debug assigned. Texture={texturePath}, Channel={channel}.");
    }

    private static void DisableOutlines()
    {
        for (var i = 0; i <= 12; i++)
        {
            var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/{i}.mat");
            if (mat == null) continue;
            mat.SetFloat("_OutlineAlpha", 0.0f);
            mat.SetFloat("_OutlineWidth", 0.0f);
        }
    }

    private static Material Mat(int index, Shader shader)
    {
        var mat = AssetDatabase.LoadAssetAtPath<Material>($"{MatRoot}/{index}.mat");
        if (mat == null)
        {
            Debug.LogWarning($"Missing material: {MatRoot}/{index}.mat");
            return null;
        }

        mat.shader = shader;
        return mat;
    }

    private static void Tex(Material mat, string property, string path)
    {
        var tex = AssetDatabase.LoadAssetAtPath<Texture2D>(path);
        if (tex == null)
        {
            Debug.LogWarning($"Missing texture for {mat.name}.{property}: {path}");
            return;
        }

        mat.SetTexture(property, tex);
    }

    private static void ApplyTextureImportSettings(bool verbose)
    {
        var changed = 0;

        AssetDatabase.StartAssetEditing();
        try
        {
            foreach (var path in ColorTexturePaths())
                changed += ConfigureTextureImporter(path, true, TextureImporterType.Default);

            foreach (var path in DataTexturePaths())
                changed += ConfigureTextureImporter(path, false, TextureImporterType.Default);

            foreach (var path in NormalTexturePaths())
                changed += ConfigureTextureImporter(path, false, TextureImporterType.NormalMap);
        }
        finally
        {
            AssetDatabase.StopAssetEditing();
        }

        AssetDatabase.SaveAssets();
        AssetDatabase.Refresh();

        if (verbose || changed > 0)
            Debug.Log($"Zhuangfy texture import settings checked. Reimported {changed} textures.");
    }

    private static int ConfigureTextureImporter(string path, bool sRgb, TextureImporterType type)
    {
        var importer = AssetImporter.GetAtPath(path) as TextureImporter;
        if (importer == null)
        {
            Debug.LogWarning($"Missing texture importer: {path}");
            return 0;
        }

        var changed = false;
        if (importer.textureType != type)
        {
            importer.textureType = type;
            changed = true;
        }

        if (importer.sRGBTexture != sRgb)
        {
            importer.sRGBTexture = sRgb;
            changed = true;
        }

        if (!changed)
            return 0;

        importer.SaveAndReimport();
        return 1;
    }

    private static string[] ColorTexturePaths()
    {
        return new[]
        {
            TexRoot + "/T_actor_common_female_emotion_atlas_01_D.png",
            TexRoot + "/T_actor_zhaungfy_body_01_D.png",
            TexRoot + "/T_actor_zhuangfy_cloth_01_D.png",
            TexRoot + "/T_actor_zhuangfy_face_01_D.png",
            TexRoot + "/T_actor_zhuangfy_hair_01_D.png",
            TexRoot + "/T_actor_zhuangfy_iris_01_D.png",
            OtherTexRoot + "/T_actor_common_body_01_RD.png",
            OtherTexRoot + "/T_actor_common_cloth_04_RD.png",
            OtherTexRoot + "/T_actor_common_cloth_04_RS.png",
            OtherTexRoot + "/T_actor_common_cloth_lut_01_D.png",
            OtherTexRoot + "/T_actor_common_face_01_RD.png",
            OtherTexRoot + "/T_actor_common_female_emotion_atlas_01_D.png",
            OtherTexRoot + "/T_actor_common_femaleskincolor01_lut_D.png",
            OtherTexRoot + "/T_actor_common_hair_01_RD.png",
            OtherTexRoot + "/T_actor_common_hair_09_RS.png",
            OtherTexRoot + "/T_actor_common_matcap_10_D.png",
            OtherTexRoot + "/T_actor_zhaungfy_body_01_D.png",
            OtherTexRoot + "/T_actor_zhuangfy_cloth_01_D.png",
            OtherTexRoot + "/T_actor_zhuangfy_face_01_D.png",
            OtherTexRoot + "/T_actor_zhuangfy_hair_01_D.png",
            OtherTexRoot + "/T_actor_zhuangfy_iris_01_D.png"
        };
    }

    private static string[] DataTexturePaths()
    {
        return new[]
        {
            OtherTexRoot + "/T_actor_chen_cloth_01_E.png",
            OtherTexRoot + "/T_actor_chen_cloth_01_ST.png",
            OtherTexRoot + "/T_actor_common_eyeshadow_01_M.png",
            OtherTexRoot + "/T_actor_common_face_01_hl_M.png",
            OtherTexRoot + "/T_actor_common_female_face_01_ST.png",
            OtherTexRoot + "/T_actor_common_female_face_01_cm_M.png",
            OtherTexRoot + "/T_actor_common_female_face_02_SDF.png",
            OtherTexRoot + "/T_actor_common_hairline_03_M.png",
            OtherTexRoot + "/T_actor_common_hairshadow_01_M.png",
            OtherTexRoot + "/T_actor_common_hairst_01_ST.png",
            OtherTexRoot + "/T_actor_zhuangfy_cloth_01_E.png",
            OtherTexRoot + "/T_actor_zhuangfy_cloth_01_P.png",
            OtherTexRoot + "/T_actor_zhuangfy_cloth_01_ST.png",
            OtherTexRoot + "/T_actor_zhuangfy_hair_01_P.png",
            OtherTexRoot + "/T_actor_zhuangfy_hair_01_ST.png",
            OtherTexRoot + "/T_fx_flow_517_M.png"
        };
    }

    private static string[] NormalTexturePaths()
    {
        return new[]
        {
            OtherTexRoot + "/T_actor_zhuangfy_cloth_01_N.png",
            OtherTexRoot + "/T_actor_zhuangfy_hair_01_HN.png"
        };
    }
}
