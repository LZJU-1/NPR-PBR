# NPR/PBR Hybrid Character Rendering

Unity URP character rendering project focused on anime-style NPR and Hybrid shading. The project explores practical shader workflows for stylized characters, including face SDF shadowing, Ramp/ILM material control, MatCap highlights, outline rendering, Hybrid PBR/NPR material response, and procedural rainy-surface preview.

## Showcase

### NPR

<video src="docs/media/01-npr.mp4" controls muted loop playsinline width="520"></video>

### NPR Shadow

<video src="docs/media/02-npr-shadow.mp4" controls muted loop playsinline width="520"></video>

### Hybrid

<video src="docs/media/03-hybrid.mp4" controls muted loop playsinline width="520"></video>

### Hybrid Shadow

<video src="docs/media/04-hybrid-shadow.mp4" controls muted loop playsinline width="520"></video>

### Rain Preview I

<video src="docs/media/05-rain-1.mp4" controls muted loop playsinline width="520"></video>

### Rain Preview II

<video src="docs/media/06-rain-2.mp4" controls muted loop playsinline width="520"></video>

### Rain Toggle

<video src="docs/media/07-rain-open-and-close.mp4" controls muted loop playsinline width="520"></video>

### Style Switching

<video src="docs/media/08-change-style.mp4" controls muted loop playsinline width="520"></video>

## Overview

This repository contains two related character rendering branches:

- NPR style: face SDF shadow, Ramp-based cel shading, ILM/LightMap material partition, MatCap highlights, rim light, and inverted-hull outline.
- Hybrid style: PBR handles clothing material details and real-time shadow response, while NPR controls face appearance, shadow hue, and stylized dark-side color.

The goal is not photorealism. The project focuses on a production-oriented stylized rendering workflow that keeps anime character readability under real-time lighting, style switching, and weather material changes.

## Features

- Character stylized shader in Unity URP.
- Face SDF shadow driven by light direction.
- Multi-row Ramp shading for material-specific dark-side colors.
- ILM/LightMap texture channels for material partition and stylized controls.
- MatCap and stylized specular highlights.
- Inverted-hull outline with smooth-normal support.
- Hybrid PBR/NPR branch for clothing, shadows, and face rendering separation.
- Runtime style switching between NPR and Hybrid looks.
- Procedural rainy material preview with cloth darkening and dynamic wet streak/highlight response.
- Editor setup workflow for character material configuration.

## Technical Notes

### NPR Branch

- `Face.shader` handles SDF face shadow, face Ramp color, MatCap response, rim light, and outline-related rendering.
- `BodyAndHair.shader` handles ILM-driven body and hair shading, Ramp selection, stylized highlights, normal-map details, and outline color control.
- SDF, Ramp, ILM/LightMap, MatCap, and normal maps form the core texture set for controllable stylized shading.

### Hybrid Branch

- PBR is used for clothing material details, metallic/smoothness response, normal details, and real-time shadow structure.
- NPR remains responsible for face rendering and dark-side hue control, avoiding over-dark or washed-out character faces under direct lighting.
- The shader blends practical PBR lighting structure with NPR color control instead of treating the full character as either purely PBR or purely flat NPR.

### Rainy Material Preview

- The rainy preview modifies material appearance procedurally, emphasizing cloth darkening, moving wet traces, and wet highlight response.
- The workflow is designed for fast preview and tuning inside Unity rather than offline texture authoring.

## Repository Layout

```text
Assets/
├── charactors/
│   ├── nahida/      # NPR character branch
│   └── zhuangfy/    # Hybrid/rain preview branch
├── Scenes/          # Unity scenes
├── Screenshots/     # Legacy screenshots
└── Settings/        # URP settings

docs/
└── media/           # README showcase videos
```

## Environment

- Unity 6000.3.14f1
- URP 17.3.0
- Input System 1.19.0

## Contributors

- [LZJU-1](https://github.com/LZJU-1): project implementation, shader development, rendering experiments, and documentation.
- Claude Code: coding and documentation assistance.
