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
