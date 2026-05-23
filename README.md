# NPR/PBR 角色渲染

Unity URP 项目，实现角色的 NPR（非真实感渲染）和 PBR（物理渲染）双风格切换。

## 当前进度

- [x] 纳西妲角色模型导入（MMD → FBX）
- [x] BodyAndHair.shader — 身体/头发 NPR 渲染（Ramp 阴影 + ILM + MatCap）
- [x] Face.shader — 脸部 SDF 方向阴影
- [x] NahidaFaceScripts.cs — 脸部光源方向实时控制
- [ ] Face.shader 补全完整光照
- [ ] PBR 渲染模式
- [ ] NPR/PBR 运行时切换

## 环境

- Unity 6000.3.14f1
- URP 17.3.0

## 目录结构

```
Assets/
├── charactors/nahida/
│   ├── shaders/       # BodyAndHair.shader, Face.shader
│   ├── Materials/      # 22 个部位材质球
│   ├── tex/            # 漫反射、法线、ILM、Ramp、MatCap
│   ├── universals/     # 脸部 SDF、金属遮罩
│   ├── Scripts/        # NahidaFaceScripts.cs
│   ├── others/         # PMX 原始模型、MMD4Mecanim 配置
│   └── 纳西妲.fbx      # 角色模型
└── Settings/           # URP 管线配置
```
