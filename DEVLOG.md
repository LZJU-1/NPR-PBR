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
