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
