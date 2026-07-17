# Link & Nexus bundle

**Meta-repository** that aggregates three architectural tiers via Git submodules:

```
T3: Link-editor (editor/)    — Dear ImGui editor, links libnexus-engine.a
T2: Nexus Engine (engine/)   — Hybrid SceneNode + Flecs ECS, delivered as static library
T1: zGameLib (engine/libs/)  — Platform, Vulkan, GPU, FrameRing (Zig modules)
```

## Architecture & Compilation Targets

> **Architecture decisions are recorded in [`docs/architecture-decisions.md`](docs/architecture-decisions.md)** — static engine library + dynamic game logic loading + script encapsulation for CI.

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
  │  Link-editor (T3)  │  │  (future)  │  │  nexus-runtime    │
  │  editor/build/bin/ │  │  Sandbox   │  │  engine/build/bin/│
  │  link-editor       │  │  Game      │  │  (no editor)      │
  └────────────────────┘  └────────────┘  └───────────────────┘
        All consumers link libnexus-engine.a (+ import nexus module for types)
```

### How this maps to Zig

| Tier | Zig mechanism | Why |
|------|--------------|-----|
| **T1 — zGameLib** | `b.addModule("zgame", ...)` — source-level Zig modules | Comptime generics, zero-overhead abstractions, and `usingnamespace` re-exports shine here |
| **T2 — Nexus** | `build-lib` → `libnexus-engine.a`; `build-runtime` → `nexus-runtime` | Cherno split: engine core as static lib, plus a no-editor runtime exe |
| **T3 — Editor** | `addImport("nexus", ...)` + `linkLibrary(nexus_lib)` — consumer exe | Separate from runtime — editor tools only, links the same static lib |

zGameLib stays as Zig modules because that's where Zig's comptime model delivers the most value (Vulkan pipeline builders, platform abstractions, FrameRing). Nexus is built as a static library to enforce the architectural boundary — consumers link `libnexus-engine.a` rather than recompiling engine source.

### Consumer hookup (Zig pattern)

Consumers import the `nexus` module for types and link the static library for the compiled engine — the same libs-first pattern zGameLib uses for its adapters:

```zig
editor_mod.addImport("nexus", nexus_dep.module("nexus"));
editor_mod.linkLibrary(nexus_dep.artifact("nexus-engine"));
```

T2 always produces `libnexus-engine.a` as its primary artifact. The module import provides the public API (`NexusApp`, servers, etc.); `linkLibrary` pulls in the pre-compiled implementation.

## Iteration & hot reload

Development iteration uses a **hybrid hot-reload strategy** — not pure DLL swapping, not restart-only:

1. **Data-driven reload** (first) — scenes, textures, locale via file watching + `ReloadEventBus`
2. **Selective code reload** (later) — gameplay in a shared library; Nexus static lib stays the stable host (Casey Muratori + Traction Point pattern)
3. **Fast restart** (always) — valid fallback when layouts change or reload is unsafe

This follows Handmade Hero's platform/game split, Hazel's asset monitoring, and Madrigal Games' practical Zig reload work. Full rationale, quotes, and citations:

**[docs/hot-reload-theory.md](docs/hot-reload-theory.md)**

## Pipeline build

```bash
# One-time setup
git submodule update --init --recursive

# Full pipeline — builds every tier in order
zig build pipeline

# Individual steps (Cherno paths on T2)
zig build build-lib       # libnexus-engine.a only (engine core)
zig build build-runtime   # nexus-runtime (no editor)
zig build build-engine    # both T2 paths
zig build build-editor    # Link-editor (T3)
zig build pipeline --summary all   # visualise the DAG
```

### Artifacts

| Command | Produces | Description |
|---------|----------|-------------|
| `zig build build-lib` | `engine/build/lib/libnexus-engine.a` | Static library — Cherno engine core (no editor) |
| `zig build build-runtime` | `engine/build/bin/nexus-runtime` | Runtime executable — engine without editor |
| `zig build build-engine` | both above | Full T2 build |
| `zig build build-editor` | `editor/build/bin/link-editor` | Editor executable (separate from runtime) |

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
├── docs/                   # Shared docs (incl. hot-reload-theory.md)
├── src/                    # Template leftovers (not compiled)
└── README.md
```
