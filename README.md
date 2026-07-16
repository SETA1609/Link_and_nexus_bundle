# Link & Nexus bundle

**Meta-repository** that aggregates three architectural tiers via Git submodules:

```
T3: Link-editor (editor/)    — Dear ImGui editor, consumes Nexus static lib
T2: Nexus Engine (engine/)   — Hybrid SceneNode + Flecs ECS, delivered as static library
T1: zGameLib (engine/libs/)  — Platform, Vulkan, GPU, FrameRing (Zig modules)
```

## Architecture & Compilation Targets

The build follows **TheCherno's recommended engine architecture** (from the Hazel series):

> *"Separate out your core engine into its own static library and then just link that to all of your executables."*

This gives a clean boundary between the engine as a product and its consumers:

```
                    ┌──────────────────────────┐
                    │  zGameLib (T1)           │  Zig modules
                    │  engine/libs/zGameLib/   │  (comptime-friendly)
                    └────────────┬─────────────┘
                                 │
                    ┌────────────▼─────────────┐
                    │  Nexus Engine (T2)       │  STATIC LIBRARY
                    │  engine/                 │  engine/build/lib/libnexus-engine.a
                    └────────────┬─────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              │                  │                  │
  ┌───────────▼────────┐  ┌─────▼──────┐  ┌────────▼──────────┐
  │  Link-editor (T3)  │  │  (future)  │  │  (future)         │
  │  editor/build/bin/ │  │  Sandbox   │  │  Runtime          │
  │  link-editor       │  │  Game      │  │  (shipping)       │
  └────────────────────┘  └────────────┘  └───────────────────┘
        All consumers link the Nexus static library
```

### How this maps to Zig

| Tier | Zig mechanism | Why |
|------|--------------|-----|
| **T1 — zGameLib** | `b.addModule("zgame", ...)` — source-level Zig modules | Comptime generics, zero-overhead abstractions, and `usingnamespace` re-exports shine here |
| **T2 — Nexus** | `b.addLibrary(.{ .linkage = .static, ... })` — static library (`libnexus-engine.a`) | The Cherno boundary: clear contract, faster consumer iteration, professional engine-as-product |
| **T3 — Editor** | `b.addExecutable(...)` + `linkLibrary(nexus_lib)` — consumer exe | Links the pre-compiled static lib, imports the `nexus` module for types |

zGameLib stays as Zig modules because that's where Zig's comptime model delivers the most value (Vulkan pipeline builders, platform abstractions, FrameRing). Nexus becomes a static library to enforce the architectural boundary — consumers (editor, games) link it rather than recompiling engine source.

## Pipeline build

```bash
# One-time setup
git submodule update --init --recursive

# Full pipeline — builds every tier in order
zig build pipeline

# Individual steps
zig build build-engine    # Nexus static lib + runtime exe
zig build build-editor    # Link-editor consumer
zig build pipeline --summary all   # visualise the DAG
```

### Artifacts

| Command | Produces | Description |
|---------|----------|-------------|
| `zig build build-engine` | `engine/build/lib/libnexus-engine.a` | Static library (Cherno boundary) |
| | `engine/build/bin/nexus-runtime` | Test runner executable |
| `zig build build-editor` | `editor/build/bin/link-editor` | Editor consumer executable |

## Standalone builds

Submodules remain fully functional in isolation:

```bash
cd engine && zig build             # → engine/zig-out/lib/ + bin/
cd engine && zig build run         # runs nexus-runtime standalone
cd engine && zig build pipeline    # per-tier pipeline step

cd editor && zig build             # → editor/zig-out/bin/link-editor
cd editor && zig build run
cd editor && zig build pipeline    # per-tier pipeline step
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
│   ├── src/
│   └── libs/zGameLib/      # T1 zGameLib (nested submodule)
├── editor/                 # T3 Link-editor (submodule)
│   ├── build.zig
│   └── src/
├── docs/                   # Shared docs
├── src/                    # Template leftovers (not compiled)
└── README.md
```
