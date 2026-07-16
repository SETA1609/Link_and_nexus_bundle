# Link & Nexus bundle

**Meta-repository** that aggregates three architectural tiers via Git submodules:

```
T3: Link-editor (editor/)     — Dear ImGui editor, consumes EditorHost
T2: Nexus Engine (engine/)    — Hybrid SceneNode + optional Flecs ECS, servers, resources
T1: zGameLib (engine/libs/)   — Platform, Vulkan, GPU, FrameRing, optional ImGui
```

## Pipeline architecture

The root `build.zig` orchestrates the build as a **Zig build DAG** (directed acyclic graph). Steps declare dependencies with `dependOn`; the build runner executes them in topological order — independent branches run concurrently, unchanged work is cached.

```
                  ┌──────────────────────┐
                  │  zGameLib (T1)       │  (built as engine dep)
                  │  engine/libs/        │
                  └──────────┬───────────┘
                             │
                  ┌──────────▼───────────┐
                  │  Nexus-engine (T2)   │  zig build build-engine
                  │  engine/             │  → engine/build/bin/nexus-engine
                  └──────────┬───────────┘
                             │
                  ┌──────────▼───────────┐
                  │  Link-editor (T3)    │  zig build build-editor
                  │  editor/             │  → editor/build/bin/link-editor
                  └──────────┬───────────┘
                             │
                  ┌──────────▼───────────┐
                  │  pipeline            │  zig build pipeline
                  │  (aggregator)        │  (the default step)
                  └──────────────────────┘
```

## Quick start

```bash
# Initialise all submodules (one-time)
git submodule update --init --recursive

# Full pipeline — builds every tier in the correct order
zig build pipeline

# Build individual tiers
zig build build-engine
zig build build-editor

# Visualise the execution graph
zig build pipeline --summary all
```

## Artifact locations

Each tier installs into its own local `build/` directory:

| Tier | Command | Artifact |
|------|---------|----------|
| Nexus-engine | `zig build build-engine` | `engine/build/bin/nexus-engine` |
| Link-editor | `zig build build-editor` | `editor/build/bin/link-editor` |

This keeps artifacts co-located with their source, matches the existing `.gitignore`, and keeps CI-friendly isolation.

## Standalone builds

Submodules remain fully functional in isolation:

```bash
cd engine && zig build          # → engine/zig-out/bin/nexus-engine
cd engine && zig build run

cd editor && zig build          # → editor/zig-out/bin/link-editor (if prerequisites exist)
cd editor && zig build run
```

## Requirements

- [Zig](https://ziglang.org/download/) **0.16.0** or newer.
- A display + Vulkan loader for `zig build run`.

## Repository structure

```
.
├── build.zig               # Pipeline orchestrator (this file)
├── AGENTS.md               # Agent guidance for AI coding assistants
├── engine/                 # T2 Nexus-engine (submodule)
│   ├── build.zig
│   ├── src/main.zig
│   └── libs/zGameLib/      # T1 zGameLib (nested submodule)
├── editor/                 # T3 Link-editor (submodule)
│   ├── build.zig
│   └── src/main.zig
├── docs/                   # Shared docs
├── src/                    # Template leftovers (not compiled)
└── README.md
```
