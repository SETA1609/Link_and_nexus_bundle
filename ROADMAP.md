# Link & Nexus Bundle — Coordinated Roadmap

**Meta-repository:** `Link_and_nexus_bundle`  
**Last updated:** July 2026  
**Strategy:** **2D-first** — ship one complete 2D game before investing in 3D.

This document is the **coordination layer**. Implementation detail lives in each tier's own roadmap:

| Tier | Repository | Submodule path | Roadmap |
|------|------------|----------------|---------|
| **T1 — zGameLib** | `SETA1609/zGameLib` | `engine/libs/zGameLib` | [`docs/ROADMAP.md`](engine/libs/zGameLib/docs/ROADMAP.md) |
| **T2 — Nexus** | `SETA1609/Nexus-engine` | `engine/` | [`docs/ROADMAP.md`](engine/docs/ROADMAP.md) |
| **T3 — Link-editor** (Crucible) | `SETA1609/Link-editor` | `editor/` | [`docs/ROADMAP.md`](editor/docs/ROADMAP.md) |

---

## Strategic direction

We are building a **three-tier modular stack** — lean foundation, hybrid engine, detachable editor — with one non-negotiable sequencing rule:

> **The first MVP and the first shippable game are 2D.**  
> A 3D version of the game and full 3D engine features come **after** that 2D game ships.

Everything on the path to **Nexus v1.0.0** (first 2D game) is designed around 2D gameplay, 2D assets, and 2D editing workflows. Post-ship work (Nexus **v2.x**, zGameLib **v2.x**) opens the 3D track without rewriting the hybrid architecture.

**Fixed architectural decisions** (all tiers):

| Decision | Where it lives |
|----------|----------------|
| Hybrid **SceneNode + optional ECS** (Flecs adapter first) | Nexus |
| **Data-driven** scenes, resources, locale — compile where possible | Nexus `build.zig` |
| **Hot reload** — hybrid: data first, selective code reload in shared lib; see [`docs/hot-reload-theory.md`](docs/hot-reload-theory.md) | Nexus + Crucible |
| **WASM modding** — sandboxed host in engine; Crucible hides compilation | Nexus `WasmHost` + Crucible build UI |
| **GameNetworkingSockets** (GNS) — full commitment, no ENet | Nexus (post–first 2D ship) |
| **Dear ImGui** — tools only (Crucible); in-game UI via **2D batcher** | zGameLib `zimgui` (late) + Nexus |
| **Raw-first** — `zgame.*` always reachable | zGameLib |

**Example-driven rule:** every version from **0.1.0** upward ships **implementation + documentation + ≥1 proving example** (`zig build <name>`).

---

## Three-tier stack (2D path)

```ascii
┌─────────────────────────────────────────────────────────────────────────┐
│  T3: LINK-EDITOR (Crucible)                              [ships v1.1.0+] │
│    2D scene tree · inspector · viewport (pan/zoom) · play-in-editor    │
│    Mod project templates · WASM build orchestration · hot reload UI     │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ EditorHost API (frozen at Nexus v1.0.0)
┌───────────────────────────────▼─────────────────────────────────────────┐
│  T2: NEXUS ENGINE                                        [→ v1.0.0 ship] │
│    Node2D · Sprite2D · Camera2D · TileMapLayer (stretch)                │
│    Flecs bridge · PhysicsServer2D · ResourceDB · scene format         │
│    WasmHost / ModManager · ReloadEventBus                               │
└───────────────────────────────┬─────────────────────────────────────────┘
                                │ zgame.* (Gpu, FrameRing, 2D batcher, zassets…)
┌───────────────────────────────▼─────────────────────────────────────────┐
│  T1: zGAMELIB                                            [→ v1.0.x gate] │
│    Vulkan + SDL3 · 2D batcher · image decode (zassets) · zaudio (late)  │
│    zClip sprite-atlas (2D animation) · zimgui (late — gates Crucible)   │
└─────────────────────────────────────────────────────────────────────────┘
```

**Post-ship 3D track** (Nexus v2.x / zGameLib v2.x): `Node3D`, `Camera3D`, depth buffers, Jolt 3D, glTF skeletal — same tiers, new examples. See [Post–first 2D game](#post-first-2d-game-3d-track) below.

---

## Master milestone map

Legend: **🎯** = required for first 2D game · **⏳** = after first 2D ship · **🔧** = editor tier

| Version | zGameLib | Nexus Engine | Link-editor | Proving example | Goal |
|---------|----------|--------------|-------------|-----------------|------|
| **0.0.1** | adapters stable | bootstrap module | — | — | Repos build; contracts in CI |
| **0.1.0** | `Gpu` + `FrameRing` ✅ | `NexusApp` loop | — | `clear-color` 🎯 | Window + clear color through Nexus |
| **0.2.0** | image decode path 🎯 | `Node2D` + `Sprite2D` | — | `textured-quad`, `node-hierarchy` 🎯 | 2D scene tree + textured draw |
| **0.3.0** | stable 2D pipelines 🎯 | ECS attach (Flecs) | — | `ecs-basic` 🎯 | Opt-in ECS mirror |
| **0.4.0** | batcher v0 🎯 | hybrid sync | — | `hybrid-sync` 🎯 | Node ↔ ECS transforms |
| **0.5.0** | input depth ✅ | `InputMap` | — | `simple-movement` 🎯 | 2D movement |
| **0.6.0** | **2D batcher shipped** 🎯 | `Camera2D` only | — | `camera` 🎯 | 2D viewports (no 3D smoke) |
| **0.7.0** | sprite animation (zClip) 🎯 | ECS particles (2D) | — | `particles` 🎯 | 2D particle heat path |
| **0.8.0** | batcher maturity 🎯 | debug overlay + **scene format** stub | — | `debug-ui` 🎯 | Data-driven scene load (minimal) |
| **0.9.0** | zaudio 🎯 | **PhysicsServer2D** + hot reload | — | `physics-ball` 🎯 | 2D physics + `ReloadEventBus` |
| **1.0.0** | zassets stable 🎯 | **`minimal-2d-game`** + `EditorHost` freeze + **WasmHost** stub | — | `minimal-2d-game` 🎯 | **Ship first 2D game** (no editor) |
| **1.1.0** | `zimgui` 🔧 | scene reload polish | **editor core** (2D) 🔧 | editor smoke | Crucible: tree, inspector, 2D viewport |
| **1.1.1** | — | mod load from disk | **mod build UI** 🔧 | `mod-demo` 🎯 | WASM compile abstraction; test mod |
| **1.2.0** | — | `LocalizationSystem` | locale tooling 🔧 | `i18n-demo` | `.po` → JSON; locale preview |
| **2.0.0** ⏳ | hello-cube, depth ⏳ | `Node3D`, `Camera3D` ⏳ | 3D viewport ⏳ | `hello-3d` ⏳ | 3D smoke after 2D ship |
| **2.1.0** ⏳ | glTF / skeletal ⏳ | 3D physics (Jolt) ⏳ | — ⏳ | `gltf-viewer` ⏳ | 3D content path |
| **2.2.0** ⏳ | GNS sibling ⏳ | multiplayer API ⏳ | net debug panel ⏳ | `net-pong` ⏳ | GNS integration |

---

## Phase 1 — Foundation to first 2D game (🎯)

**Target:** Nexus **v1.0.0** with a small but **complete** 2D title (platformer, top-down, or pong-plus) built only from `nexus.*` public APIs — no Crucible required to play.

### What “2D-first” means in practice

| Area | In scope before v1.0.0 | Deferred to v2.x |
|------|------------------------|------------------|
| Scene nodes | `Node2D`, `Sprite2D`, `Camera2D`, `TileMapLayer` (stretch) | `Node3D`, mesh instances |
| Rendering | Orthographic 2D batcher, sprites, atlases | Perspective, depth, PBR |
| Physics | **2D** rigid bodies | Jolt 3D |
| Animation | Sprite sheets / zClip atlas | glTF skeletal |
| Camera | `Camera2D`, follow, bounds | `Camera3D`, orbit |
| Modding | `WasmHost` + `ModManager` API at v1.0.0 | Full Crucible build UI at v1.1.1 |
| Networking | — | GNS at v2.2.0 |
| Editor | — | Crucible at v1.1.0+ |

### Coordination gates (critical path)

These cross-repo dependencies block the 2D game if they slip:

```ascii
zGameLib 0.4.0 (2D batcher v0)
    └──► Nexus 0.2.0–0.7.0 (Sprite2D, HUD, particles)

zGameLib 0.7.0 (zassets image decode)
    └──► Nexus 0.2.0 (textured-quad)

zGameLib 0.9.0 (zaudio)
    └──► Nexus 1.0.0 (minimal-2d-game audio)

Nexus 1.0.0 (EditorHost frozen)
    └──► Link-editor 1.1.0 (editor core)

zGameLib 1.1.0 (zimgui)
    └──► Link-editor 1.1.0 (ImGui panels)
```

### Data-driven + hot reload (2D game scope)

Designed for the first 2D title from the start:

1. **v0.8.0** — minimal scene/resource format; load `Sprite2D` trees from disk.
2. **v0.9.0** — `ResourceDB` + `ReloadEventBus`; texture and scene data hot reload.
3. **v1.0.0** — `project.nexus` settings; mod packages (`mod.json` + optional `mod.wasm`).
4. **v1.1.0+** — Crucible file watcher drives `EditorHost.reimport` / `reloadScene`.

**Code hot reload (Zig)** is **selective, not universal** — gameplay/tool code in a future shared library reloads while `libnexus-engine.a` stays stable; restart remains the fallback. See [`docs/hot-reload-theory.md`](docs/hot-reload-theory.md).

---

## Phase 2 — Editor + modding polish (🔧)

**Target:** Nexus **v1.1.x**–**v1.2.0** with Link-editor consuming frozen `EditorHost`.

Crucible is **2D-native** at launch:

- Scene tree and inspector for `Node2D` / `Sprite2D` / `Camera2D`
- Viewport: pan, zoom, grid — not orbit camera
- Play-in-editor with scene fork
- Asset browser for 2D textures and atlases
- **Mod project wizard** — Zig/Rust templates, “Build Mod” button, WASM toolchain hidden
- Hot reload UI for resources, scenes, and WASM modules

Localization (v1.2.0) uses the same data-first pipeline: translators edit `.po`, `build.zig` compiles to JSON, Crucible previews locales.

---

## Post–first 2D game (3D track) (⏳)

After the 2D game ships and the 0.1.0→1.0.0 ladder is proven:

| Pillar | Direction |
|--------|-----------|
| **3D rendering** | zGameLib depth + `hello-cube`; Nexus `Node3D` / `Camera3D` |
| **3D assets** | glTF via zClip; skeletal animation |
| **3D physics** | Jolt backend behind `PhysicsServer` |
| **3D editor** | Crucible orbit viewport, 3D gizmos, mesh inspector |
| **Multiplayer** | GNS sibling + Nexus `MultiplayerAPI` |
| **Web** | WASM + WebGPU backend (see Nexus theory/12) |

The **hybrid SceneNode + ECS** model does not change — 3D nodes attach to the same bridge.

---

## Example ladder (cross-tier)

```ascii
T1 zGameLib          T2 Nexus                    T3 Link-editor
────────────────     ──────────────────────      ─────────────────
clear-color-2 ✅  →  clear-color (0.1.0) 🎯
space-invaders    →  textured-quad (0.2.0) 🎯
                     node-hierarchy (0.2.0) 🎯
                     ecs-basic (0.3.0) 🎯
                     hybrid-sync (0.4.0) 🎯
                     simple-movement (0.5.0) 🎯
                     camera (0.6.0) 🎯  [Camera2D]
                     particles (0.7.0) 🎯
                     debug-ui (0.8.0) 🎯
                     physics-ball (0.9.0) 🎯  [2D physics]
                     minimal-2d-game (1.0.0) 🎯  ← FIRST SHIP
                                               →  editor smoke (1.1.0) 🔧
                                               →  mod-demo (1.1.1) 🔧
                     i18n-demo (1.2.0)      →  locale panels (1.2.0) 🔧
hello-cube (2.0.0)⏳ →  hello-3d (2.0.0) ⏳  →  3D viewport (2.0.0) ⏳
```

---

## Submodule workflow

```sh
# Initial setup
git submodule update --init --recursive

# Build per tier
cd engine && zig build          # Nexus-engine
cd editor && zig build          # Link-editor
```

When updating roadmaps, edit the **canonical file in each submodule**, then bump the meta-repo submodule pointer. Keep version tables in sync — the master map above is the source of truth for cross-tier alignment.

---

## Risks

| Risk | Mitigation |
|------|------------|
| 2D batcher slips | Interim quad path in Nexus `RenderingServer`; zGameLib Phase 1 priority |
| Scope creep into 3D pre-1.0 | Explicit **🎯 / ⏳** markers in all tier roadmaps |
| Crucible before `EditorHost` freeze | Link-editor stays on v1.1.0+ gate |
| WASM toolchain friction | Crucible templates + data-only mods without `.wasm` |
| Docs ahead of code | `Nexus_Reference.md` marks **shipped** vs **planned** per version |

---

## See also

- [`AGENTS.md`](AGENTS.md) — repo layout and build commands
- [Nexus Reference](engine/docs/Nexus_Reference.md) — authoritative Tier 2 API
- [Nexus theory ladder](engine/docs/theory/README.md) — architecture rationale
- [WASM modding](engine/docs/theory/13-wasm-modding.md) · [GNS decision](engine/docs/theory/11-networking-decision.md)
- [**Hybrid hot-reload theory**](docs/hot-reload-theory.md) — bundle-level strategy + citations (Casey, Cherno, Traction Point)
- [Hot reload (engine)](engine/docs/theory/08-hot-reload-nexus-engine.md) · [Crucible hot reload](engine/docs/theory/09-hot-reload-crucible.md)