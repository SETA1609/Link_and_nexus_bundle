# Link & Nexus bundle — agent instructions

## What this repo is

A **meta-repository** (bundle) that aggregates three tiers via Git submodules:

| Tier | Repo | Submodule path | Tracks branch |
|------|------|----------------|---------------|
| T1 — zGameLib | `SETA1609/zGameLib` | `engine/libs/zGameLib` | `feat/engine-docs-ref` |
| T2 — Nexus Engine | `SETA1609/Nexus-engine` | `engine/` | `main` |
| T3 — Link-editor | `SETA1609/Link-editor` | `editor/` | `main` |

The real code lives in the submodules. The root `src/`, `build.zig`, and `README.md` are a **stale cpp-zig-hybrid-template** — not representative of the actual architecture.

## Initial setup

```sh
git submodule update --init --recursive
```

## Build & run per tier

```sh
cd engine && zig build          # Nexus Engine → zig-out/bin/nexus-engine
cd engine && zig build run

cd editor && zig build          # Link-editor → zig-out/bin/link-editor
cd editor && zig build run
```

Requires Zig **0.16.0** (pinned in CI by `mlugg/setup-zig@v2`). Windows/macOS/Linux all in scope. `zig build run` needs a display + Vulkan loader; the CI `run` step will fail in a headless environment.

**Current build status**: both engine and editor are pre-implementation (bootstrap). Engine fails due to incomplete zGameLib dependency chain; editor config has been fixed.

## Architecture (three tiers)

```
T3: Link-editor (editor/)     — Dear ImGui editor, consumes EditorHost
T2: Nexus Engine (engine/)    — Hybrid SceneNode + optional Flecs ECS, servers, resources
T1: zGameLib (engine/libs/)   — Platform, Vulkan, GPU, FrameRing, optional ImGui
```

- Engine entrypoint: `engine/src/main.zig` → imports `zgame`, creates Vulkan window loop.
- Editor entrypoint: `editor/src/main.zig` → imports `nexus`, EditorHost consumer.
- Engine source of truth: `engine/docs/Nexus_Reference.md`, `engine/docs/theory/`, `engine/build.zig`.
- Editor source of truth: `editor/docs/`, `editor/build.zig`.

## Key gotchas

- **No tests** anywhere. No `zig build test` step.
- **engine/AGENTS.md** contains engine-specific agent guidance — source of truth for that tier.
- **Root `README.md` is stale** — describes the old cpp-zig-hybrid-template, not the 3-tier architecture.
- **`build/` is gitignored** (standard Zig build output).
- **C/C++ dirs** (`src/c/`, `src/cpp/`) are template leftovers — **not compiled** by engine or editor builds.
