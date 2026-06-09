# 开发日志

## 2026-05-24

### 修复：Face.shader SDF 阴影边缘锯齿

**问题**：脸部 SDF 阴影在特定光源角度（如 Y=110°~123°）时，亮暗分界线出现明显锯齿/破碎。

**原因**：
1. `acos()` 输入未 clamp 到 `[-1, 1]`，浮点误差导致返回 NaN
2. SDF 贴图（FaceLightmap.png）开启了 MipMap，远距离使用低分辨率 Mip 级别加剧锯齿

**修复**：
- `Face.shader`：clamp acos 输入、处理 LpHead 近零情况、saturate pow 输入
- `FaceLightmap.png`：关闭 MipMap（`enableMipMap: 0`），保留 Bilinear 过滤

### 修复：数据贴图 MipMap 导致渲染瑕疵

**问题**：ILM、Ramp、MetalMap 等 NPR 数据贴图默认开启 MipMap，远距离时采样到低分辨率 Mip 级别，可能导致：
- Ramp 阴影颜色偏移
- ILM 材质通道（阴影强度/高光/金属度）错位
- 金属遮罩边界锯齿

**修复**：以下贴图统一关闭 MipMap：
- `Body_Lightmap.png` / `Hair_Lightmap.png`（ILM 贴图）
- `Body_Shadow_Ramp.png` / `Hair_Shadow_Ramp.png` / `Body_Specular_Ramp.png`（Ramp 贴图）
- `Face_Shadow.png`（脸部 Ramp）
- `MetalMap.png`（金属遮罩）

**保留 MipMap 的贴图**：法线贴图（需要 MipMap 抗高光锯齿）、颜色贴图（标准做法）

---

## 2026-05-25

### 完成 Face.shader 脸部渲染管线

从 SDF 调试输出（黑白蒙版）改为完整 NPR 渲染，4 步管线：

1. **基础色** — AmbientColor + DiffuseColor 混合作为底色，叠乘 BaseTex（颜.png）和 ToonTex（toon_defo.bmp MatCap）
2. **Ramp 阴影色** — 从 Face_Shadow.png 的暗色端采样，_RampRow=5 选脸部行，根据光源 Y 分量做日夜插值
3. **SDF 阴影蒙版** — FaceLightmap.png（R 通道）存储每像素阴影阈值，与光源方向角度（立方映射）比较，硬切产生阴影形状
4. **合成** — sdf=1 亮面直接用 baseColor，sdf=0 暗面用 `baseColor × rampColor × ShadowColor`

**使用贴图**：颜.png（漫反射）、Face_Shadow.png（阴影 Ramp）、FaceLightmap.png（SDF 阈值）、toon_defo.bmp（MatCap）

### 修复：脸部下半部分异常暗色

**问题**：面部鼻子以下到下巴区域始终偏暗，看起来像有阴影。该暗色不随光源方向变化，旋转角色 180° 后暗部移至额头。

**排查过程**：
1. 绕过 SDF（直接输出 baseColor）→ 暗部仍在 → 排除 SDF
2. 移除 Unity Shadow Map（GetMainLight 不传 shadowCoord）→ 仍在 → 排除 Shadow Map
3. 检查颜.png 贴图 → 无 AO 烘焙
4. 临时禁用 ToonTex（_ToonTexFac=0）→ **暗部消失** → 定位到 MatCap

**根因**：`toon_defo.bmp` 是通用卡通 MatCap 贴图，上半亮、下半暗。脸部法线朝下的面片（下巴、鼻下）的法线在视空间 Y 分量为负 → matcapUV.y 落在 MatCap 下半暗色区 → baseColor 被乘以暗色值 → 看起来像 AO 阴影。切换到皮肤/头发专用 MatCap 后正常。

**修复**：
- Face/Body 的 `_ToonTex`：`toon_defo.bmp` → `skin.bmp`
- Hair 的 `_ToonTex`：`toon_defo.bmp` → `hair.bmp`

---

### 添加 Face.shader 描边 Pass（Cull Front 膨胀法）

**Pass 组织结构**：

```
SubShader
├── Pass 0: ShadowCaster     (LightMode="ShadowCaster")     — 向 Shadow Map 写深度
├── Pass 1: DepthNormals     (LightMode="DepthNormals")     — 供 SSAO 等屏幕特效
├── Pass 2: UniversalForward (LightMode="UniversalForward") — 主渲染
└── Pass 3: DrawOutline      (无 LightMode)                 — 背面膨胀描边
```

每个 Pass 是独立编译的 HLSL 程序，有自己的 CBUFFER、顶点/片元着色器。
变量名（如 `_OutlineOffset`）在不同 Pass 的 CBUFFER 中可以重复声明，不会冲突。

**DrawOutline Pass 实现步骤**：

1. **Properties** 中声明 `_OutlineColor` (Color) 和 `_OutlineOffset` (Float)
2. 新建 Pass，Name = "DrawOutline"
3. Tags 填 `"RenderPipeline"="UniversalPipeline"` `"RenderType"="Opaque"`，**不加 LightMode**
4. `Cull Front` — 只渲染背面
5. 顶点着色器：`vertex.xyz + normal.xyz * _OutlineOffset` 沿法线外扩顶点
6. 片元着色器：直接输出 `_OutlineColor`，混合 `MixFog`

**关键点**：
- **Cull Front** 是整个技术的核心——利用背面的额外几何产生描边
- **不加 LightMode** 标签，URP 以默认方式处理（加了反而可能不渲染）
- 材质中的 `_OutlineColor` alpha 必须为 1，否则描边透明不可见
- 材质中的 `_OutlineOffset` 会覆盖 Shader 默认值，需在 Inspector 中调整

**踩坑记录**：
- `_OutlineColor` alpha 初始为 0 → 描边完全透明，看不出效果
- `_OutlineOffset` 材质旧值 0.000015 覆盖了 Shader 默认 0.0003 → 描边太细
- 尝试加 `LightMode = "SRPDefaultUnlit"` 导致 Pass 不渲染

---

### 实现 BodyAndHair 描边（ILM.a 多色 + clip 遮罩）

**实现方式**：参考教程，在 BodyAndHair.shader 末尾添加 DrawOutline Pass。

**与 Face.shader 描边的关键区别**：

| | Face | BodyAndHair |
|---|---|---|
| 描边颜色 | 单色 `_OutlineColor` | 5 色 `_OutlineMapColor0~4` |
| 颜色选择 | 固定 | ILM.a 通道 → 材质类型枚举 → 级联 lerp |
| 纹理依赖 | 无 | `_ILM`（A 通道）、`_BaseTex`（UV 变换） |
| 语法 | URP `TEXTURE2D`/`SAMPLER` | CG `sampler2D`/`tex2D`（避免跨 Pass 冲突） |

**ILM.a → 描边颜色映射逻辑**：

```
ilm.a ∈ [0.00, 0.15) → _OutlineMapColor0
ilm.a ∈ [0.15, 0.40) → _OutlineMapColor1
ilm.a ∈ [0.40, 0.60) → _OutlineMapColor2
ilm.a ∈ [0.60, 0.85) → _OutlineMapColor3
ilm.a ∈ [0.85, 1.00] → _OutlineMapColor4
```

与主 Pass 的 Ramp 行选择使用完全相同的级联 lerp 逻辑。

**薄面（裙摆）全黑问题的解决**：

- **现象**：裙摆下方整块黑色，不是细描边线
- **原因**：裙摆是单层面片（2D 薄面），Cull Front 膨胀后整张背面都可见，不像实体体积会被自身遮挡
- **解决**：在片元着色器添加 `clip(color.a - 0.01)`，将裙摆材质对应的 `_OutlineMapColor` 的 Alpha 设为 0 → 片元被丢弃 → 不画描边

**踩坑记录**：
- 材质 `_OutlineOffset` 被旧值 `0.000015` 覆盖 → 描边肉眼不可见 → 改为 `0.002`
- 尝试 `v.color.r` 顶点色控制外扩 → 无效（模型未存储该数据）
- 尝试 `v.tangent` 外扩 → 方向不对称，脸部不适用
- BodyAndHair 不能用 Face 的纯 `TEXTURE2D` 声明 → 与主 Pass 冲突 → 用 `sampler2D`/`tex2D` 旧语法

---

### 修复硬边处描边断裂（平滑法线 + 面积权重）

**问题**：角色硬边处（肩膀、腿部等）描边出现断裂/缺口。同一位置存在多个顶点（各自独立法线），Cull Front 外扩时各顶点沿各自法线方向走 → 硬边处张开。

**解决方案**：烘焙平滑法线脚本 `NahidaSmoothNormal.cs`

```
原理：
  同位置多顶点 → 加权平均法线 → 存入 mesh.uv3 (TEXCOORD2)
  Outline Pass 读取 v.texcoord2.xyz 替代 v.normal.xyz 作为外扩方向
```

**失败的尝试**：

| 存储通道 | 问题 |
|---|---|
| `mesh.tangents` | 覆盖了 TBN 矩阵的 tangent，主渲染法线贴图崩溃（布料出现三角形块）|
| `mesh.colors` | GPU 端 Color 通道是 UNORM 格式，负数被截断为 0，方向完全错误 |
| `mesh.SetUVs(1, Vector3)` | 格式不兼容，TEXCOORD1 无数据 |

**最终方案**：`mesh.SetUVs(2, Vector4)` → UV3 通道 → Shader 读 `TEXCOORD2`

- `Vector4` 格式天然支持负数，不需要编解码
- UV3 通道不影响主渲染的 TBN 矩阵
- **面积权重**（`useAreaWeight`）：大三角面对平滑方向贡献更大，小面影响小，结果更自然
- Face.shader **不用平滑法线**（`v.normal.xyz`），因为嘴巴凹陷处平滑后会出错

**使用**：脚本挂到 SkinnedMeshRenderer 所在 GameObject，Play 时 Awake 自动执行。也可右键 → "执行平滑" 手动触发。

---

### 边缘光（纯菲涅尔）

**方案**：`pow(1 - NoV, _RimPower) * _RimIntensity * _RimColor`，加法混合到 albedo/diffuse。

**参数**：`_RimColor`（颜色）、`_RimPower`（衰减锐度，默认 4）、`_RimIntensity`（强度，默认 0.3）。

**踩坑**：教程的深度差方案（`SampleSceneDepth` + `normalVS.x` 偏移）尝试 6 次均失败：
- `normalVS.x` 翻转产生接缝 → 改四方向采样 → 仍有接缝
- `positionNDC` 范围 NDC vs UV 不一致 → 采样偏移错位
- 披风深度信息串扰到身体 → 非预期光晕

**最终选择纯菲涅尔**：无深度纹理依赖、无方向翻转、无接缝，已在两个 Shader 中稳定运行。

---

## NPR 阶段完成总结 (2026-05-30)

### Face.shader
- SDF 脸部方向阴影（FaceLightmap.png R 通道 + 光源角度）
- Ramp 阴影色（Face_Shadow.png）
- ShadowTex G/A 通道调制（阴影衰减 + 强制高亮）
- MatCap 卡通光照（skin.bmp）
- 纯色背面膨胀描边（Cull Front，`v.normal` 外扩）
- 纯菲涅尔边缘光

### BodyAndHair.shader
- ILM 四通道 NPR 管线（R=金属度, G=阴影软硬, B=高光遮罩, A=材质类型）
- Ramp 5 行材质选择（与 ILM.a 联动）
- Blinn-Phong 高光（金属/非金属分离）
- MatCap 光照 + 球面反射
- 法线贴图细节
- ILM.a 多色描边（BaseTex 自动采样颜色）
- 薄面 clip 遮罩（`clip(color.a)`）
- 平滑法线（面积权重，UV3 通道）
- 纯菲涅尔边缘光

---

### 分割线 NPR/PBR 实时对比工具

**实现方式**：BodyAndHair.shader 的片元着色器中，每像素根据屏幕坐标判断在分割线的哪一侧 → 走 NPR 或 PBR 分支。单相机、单 Pass、不额外渲染。

**关键算法**：
- `GetNormalizedScreenSpaceUV(input.positionCS)` → 屏幕像素坐标
- Y 轴翻转为 GUI 方向（top=0），与 OnGUI 分割线坐标系统一
- `dot(pixelPos - screenCtr, perp) - offsetPx` 判断像素在线哪一侧
- `splitSide > 0` = NPR，`splitSide <= 0` = PBR

**控制器**：SplitScreenController（左键旋转、右键平移、R 重置），每帧写入 `_SplitLineDirX/Y`、`_SplitLineOffset`、`_SplitLineOffsetPx` 全局 Shader 参数。

**踩坑**：NDC 与 GUI 坐标系不一致导致分割线错位 — 最终通过 Y 轴翻转 + 像素空间统一计算解决。

---

### PBR 阴影抖动修复

**问题**：PBR 模式下旋转平行光时，角色表面阴影边缘出现明显的像素级跳动/闪烁。NPR 侧不受影响（使用自绘 Ramp/SDF 阴影）。

**原因**：PBR 路径调用 `UniversalFragmentPBR`，内部使用 `mainLight.shadowAttenuation`，依赖 Unity 的实时 Shadow Map。Shadow Map 是离散采样——4096 像素覆盖整个阴影距离范围，每个像素对应世界空间几厘米。灯光旋转时，阴影边缘的采样点在世界空间中移动，映射到 Shadow Map 不同像素→产生阶梯状跳动。

另一个重要因素：**Normal Bias** 把阴影采样点沿表面法线偏移一段距离，灯光角度一变，偏移方向跟着变→阴影边缘"游动"比物理精度问题更明显。

**修复步骤**：

1. **Shadow Resolution** `2048` → `4096`（像素密度翻倍）
2. **Normal Bias** `0.5` → `0.05`（大幅减小法线偏移，核心修复）
3. **Depth Bias** `0.1` → `0.05`
4. **Cascade Count** `4` → `1`（单 Cascade，全部分辨率集中在角色身上）
5. **Shadow Distance** `50` → `15`（4096 像素只覆盖 15 单位，每像素精度最大化）

**结论**：大幅改善但无法完全消除——Shadow Map 的离散采样本质决定了转动灯光时边缘必然有微小的像素级跳动，这是实时渲染的物理极限。NPR 侧完全不受此影响。

---

## 2026-06-07

### PBR 风格化暗部：混合 NPR Ramp 色相

**目标**：PBR 分支不追求纯物理写实，而是接近《明日方舟：终末地》一类角色效果：

```
PBR 负责：法线细节 / 高光结构 / 金属感 / 光滑度
NPR 负责：暗部色相 / 角色肤色氛围 / Ramp 阴影美术控制
```

**问题 1：Unity 原生 PBR 阴影过黑**

PBR 路径调用 `UniversalFragmentPBR(inputData, surfaceData)`，内部使用 Unity 实时阴影。角色背光或落入 Shadow Map 时，暗部会被压得过黑，和 NPR 侧温暖、可控的 Ramp 暗部差异太大。

**初始修复：加法补光**

第一版尝试在 PBR 结果后叠加环境补光和阴影补光：

```
albedo += Ambient * baseTex
albedo += shadowMask * baseTex * shadowFillColor
```

该方法能明显提亮暗部，但出现新问题：

- 皮肤和白发本身是高明度、低饱和贴图，加法补光会把 RGB 三通道一起推向 1
- 结果是皮肤、头发被“冲白”，原本的肤色和发色层次被洗掉
- 补光越强，越像在材质上盖了一层白粉，而不是恢复角色暗部

**结论**：暗部不能靠继续加亮解决，必须保留/借用 NPR Ramp 的色相。

### 最终方案：PBR 光照结构 + NPR 暗部色相

保留 PBR 的 `UniversalFragmentPBR` 作为基础光照：

```
float4 pbrLit = UniversalFragmentPBR(inputData, surfaceData);
float3 pbrColor = pbrLit.rgb;
```

然后构造风格化阴影遮罩：

```
float realtimeShadow = 1.0 - saturate(light.shadowAttenuation);
float rampShadow = 1.0 - lambertStep;
float wrappedBackLight = 1.0 - smoothstep(0.15, 0.85, halfLambert);
float stylizedShadowMask = saturate(max(realtimeShadow, max(rampShadow, wrappedBackLight)));
```

三个来源分别对应：

- `realtimeShadow`：Unity 原生 Shadow Map 的阴影区域
- `rampShadow`：NPR Ramp 硬/软分界的暗部区域
- `wrappedBackLight`：背光面补充遮罩，避免没有实时阴影时背面仍然过亮或过灰

暗部颜色不再加法提亮，而是向 NPR 已经算好的阴影色混合：

```
float3 nprTone = lerp(grayShadowColor, diffuse, _PBRNPRToneStrength);
float shadowBlend = stylizedShadowMask * _PBRNPRShadowBlend;
float3 pbrWithRampTone = lerp(pbrColor, nprTone, shadowBlend);
```

这样：

- 亮面仍保留 PBR 的高光、法线、金属质感
- 暗部逐渐回到 NPR Ramp 的暖色/材质色相
- 皮肤不会被加法补光冲白，能保留 NPR 侧的肤色感觉
- 白发暗部能回到灰蓝/灰紫层次，而不是整体雪白

最后加一个很弱的暗部下限，防止原生阴影完全压死：

```
float3 shadowFloorColor = baseTex.rgb * _AmbientColor.rgb;
pbrWithRampTone = max(pbrWithRampTone, shadowFloorColor * stylizedShadowMask * _PBRShadowFloor);
```

### 修复：ILM.b 不能作为 PBR AO

之前 PBR 分支直接使用：

```
surfaceData.occlusion = ilm.b;
```

但在当前 NPR 管线中，`ILM.b` 的语义是**高光遮罩**，并不是真正的 AO/Cavity。直接当 PBR occlusion 会把很多非高光区域错误压暗。

改为轻量遮蔽：

```
surfaceData.occlusion = lerp(1.0, saturate(ilm.b), _PBROcclusionStrength);
```

默认 `_PBROcclusionStrength = 0.12`，只保留一点局部明暗变化，避免二次压黑。

### 新增 PBR 调节参数

| 参数 | 默认值 | 作用 |
|---|---:|---|
| `_PBROcclusionStrength` | `0.12` | ILM.b 参与 PBR occlusion 的强度，越高暗部越容易脏 |
| `_PBRIndirectStrength` | `0.12` | 额外环境光强度，只做轻微托底 |
| `_PBRNPRShadowBlend` | `0.65` | 阴影区域向 NPR Ramp 色相混合的强度 |
| `_PBRNPRToneStrength` | `0.45` | 在 `grayShadowColor` 和 `diffuse` 之间选暗部色调 |
| `_PBRShadowFloor` | `0.35` | 暗部最低亮度下限，防止 Shadow Map 纯黑 |

### 当前结论

这一路径比“纯 PBR + 补光”更适合角色展示：

- **PBR** 提供材质结构与高光可信度
- **NPR Ramp** 提供角色色彩设计与暗部审美
- 现有 ILM/Ramp 贴图仍可复用，不需要立刻制作新资产

但如果要继续逼近商业项目质量，后续仍建议补充 PBR 专用资产：

- 真正的 AO/Cavity 贴图
- Roughness/Smoothness 贴图
- 更干净的 Metallic Mask
- 皮肤、头发、布料、金属的材质分区 Mask
- 头发各向异性高光方向/强度控制

---

## 2026-06-09

### 庄方宜：Endfield Hybrid Shader 当前实现

**目标**：给新角色庄方宜搭建接近《明日方舟：终末地》方向的 PBR/NPR 混合材质。整体思路不是完全复刻 Nahida 的 NPR 管线，而是让：

```
PBR 负责：法线细节 / 高光结构 / 金属感 / 光滑度 / 布料金属差异
NPR 负责：脸部 SDF 阴影 / 暗部色相 / Ramp 美术控制 / 角色肤色稳定性
```

### 脸部：避免被 URP 物理阴影压暗

**问题**：即使 `_RealtimeShadowStrength = 0`，脸部仍然偏暗。原因是 `UniversalFragmentPBR(inputData, surfaceData)` 内部已经计算了 URP Shadow Map，`pbrColor` 本身就是被物理阴影压暗后的结果。

**修复**：在 `EndfieldHybrid.shader` 中新增无 Shadow Map 的 NPR 亮面底色：

```
float wrappedLight = lerp(NoL, halfLambert, _NPRLightWrap);
float3 nprLitBase = lutBase * lerp(0.92, 1.08, saturate(wrappedLight)) * _NPRLitBoost;
float3 litBaseColor = lerp(nprLitBase, pbrColor, _PBRBaseBlend);
```

脸部材质默认：

| 参数 | 默认值 | 作用 |
|---|---:|---|
| `_PBRBaseBlend` | `0.08` | 脸部亮面大部分走 NPR base，少量保留 PBR 质感 |
| `_NPRLightWrap` | `1.0` | 用 half-Lambert 包裹光照，避免脸部亮面受光角过硬 |
| `_NPRLitBoost` | `1.08` | 轻微提高脸部整体亮度 |
| `_ShadowFloor` | `0.62` | 抬高脸部暗部最低亮度，避免脏黑 |

这样脸部亮面不再主要依赖 PBR 的 Shadow Map，SDF 块状阴影仍然保留。

### 脸部 SDF：方向与 Nahida 对齐

庄方宜的 `T_actor_common_female_face_02_SDF.png` 不是单通道 SDF。通道检查后判断：

- R/G：左右方向 SDF 梯度
- B：更宽的正面渐变
- A：局部遮罩，不适合作为主阴影

当前使用 `_SDFDirectionalRG = 1`，并保持 `_SDFSwapRG = 0`。这个配置与 Nahida 的 `Face.shader` 中：

```
float mixSdf = lerp(sdfRight, sdfLeft, exposRight);
```

保持同一类阴影推进方向。`Swap Directional RG On/Off` 只保留为调试菜单，不作为默认值。

### 衣服与布料：当前质感来源

衣服材质使用同一个 `EndfieldHybrid.shader`，但与脸部不同，衣服默认仍以 PBR 底色为主，叠加 NPR 暗部/Ramp 色相。当前贴图绑定：

| Shader 输入 | 贴图 | 用途 |
|---|---|---|
| `_BaseTex` | `T_actor_zhuangfy_cloth_01_D.png` | 布料/金属基础色 |
| `_NormalTex` | `T_actor_zhuangfy_cloth_01_N.png` | 布料褶皱、硬表面细节 |
| `_ParamTex` | `T_actor_zhuangfy_cloth_01_P.png` | PBR 参数：R 控 metallic，G 控 smoothness，B 控 occlusion |
| `_StyleTex` | `T_actor_zhuangfy_cloth_01_ST.png` | 风格化 Ramp 分界调制 |
| `_RampTex` | `T_actor_common_cloth_04_RD.png` | 布料暗部 Ramp 色相 |
| `_SpecRampTex` | `T_actor_common_cloth_04_RS.png` | 布料/金属高光 Ramp |
| `_LutTex` | `T_actor_common_cloth_lut_01_D.png` | 布料整体色彩校正 |
| `_MatCapTex` | `T_actor_common_matcap_10_D.png` | 视角相关高光/材质反射补充 |
| `_MaskTex` / `_EmissionTex` | `T_actor_zhuangfy_cloth_01_E.png` | 局部遮罩和轻微发光 |
| `_FlowTex` | `T_fx_flow_517_M.png` | 目前仅作为 emission mask 的补充，尚未实现动态流动 |

衣服默认参数：

| 参数 | 默认值 | 效果 |
|---|---:|---|
| `_NormalStrength` | `1.0` | 启用法线细节，是布料褶皱质感的主要来源 |
| `_MetallicScale` | `0.45` | 允许 `_P` 图中的金属区域显出 PBR 金属感 |
| `_SmoothnessScale` | `0.85` | 提供偏亮、偏干净的高光结构 |
| `_SpecRampStrength` | `0.35` | 用 RS 贴图加强风格化高光 |
| `_MatCapStrength` | `0.12` | 补一点视角相关反射 |
| `_StyleRampStrength` | `0.15` | 让布料暗部不是纯 Lambert，而受 ST 图调制 |
| `_RealtimeShadowStrength` | `0.75` | 衣服保留较强场景阴影，和脸部区分开 |

**当前判断**：衣服/布料的渲染方式没有明显逻辑问题。质感主要来自 PBR 参数图、法线贴图、RS 高光 Ramp 和 MatCap，而不是单纯靠提亮或 Ramp 上色。脸部已经从 PBR 阴影中解耦，衣服保留 PBR 阴影更合理，因为布料、金属、硬表面的体积感需要场景光参与。

### 当前未完成项

目前还没有真正实现终末地一类雨天/湿润材质效果。已有 `_FlowTex` 和 `_EmissionTex` 入口，但只是静态参与 emission mask，没有时间流动、雨滴法线、湿润粗糙度变化。

后续如果做雨天效果，建议新增：

- `_Wetness`：全局湿润强度
- `_WetMask`：不同材质吸水/挂水强度
- `_DropletNormalTex`：水滴法线
- `_WetDarken`：布料吸水变深
- `_WetSmoothnessBoost`：皮革/金属 wet 后更光滑
- `_FlowSpeed`：雨痕或能量流动速度

材质规则建议：

- 布料/棉布：湿润后 base color 变深，高光只轻微增强
- 皮革/金属：湿润后 smoothness 增强，高光更集中，叠加水滴 normal
- 脸部皮肤：不做大面积雨滴，最多做非常弱的高光/湿润边缘，避免破坏角色脸部可读性
