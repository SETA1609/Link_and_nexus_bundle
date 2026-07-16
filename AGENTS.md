# Link & Nexus bundle — agent instructions

## What this repo is

A **meta-repository** (bundle) that aggregates three tiers via Git submodules:

| Tier | Repo | Submodule path | Tracks branch |
|------|------|----------------|---------------|
| T1 — zGameLib | `SETA1609/zGameLib` | `engine/libs/zGameLib` | `feat/engine-docs-ref` |
| T2 — Nexus Engine | `SETA1609/Nexus-engine` | `engine/` | `main` |
| T3 — Link-editor | `SETA1609/Link-editor` | `editor/` | `main` |

The real code lives in the submodules. The root `src/`, and parts of `README.md` are a **stale cpp-zig-hybrid-template** — not representative of the actual architecture.

## Architecture (Cherno model)

Follows TheCherno's recommended pattern: core engine as a **static library**, with editor and future game executables as consumers.

```
T3: Link-editor (editor/)    — exe linking libnexus-engine.a (Hazelnut — editor only)
T2: Nexus Engine (engine/)   — libnexus-engine.a + nexus-runtime (Hazel — no editor)
T1: zGameLib (engine/libs/)  — Zig modules (comptime-friendly)
```

Zig adaptation:
- **T1** uses `b.addModule` (source-level modules — where comptime shines)
- **T2** `build-lib` → `b.addLibrary(.{ .linkage = .static })` from `src/root.zig`; `build-runtime` → thin `src/runtime/main.zig` consumer
- **T3** uses `b.addExecutable` + `addImport("nexus", ...)` + `linkLibrary(nexus_lib)` (editor consumer)

## Initial setup

```sh
git submodule update --init --recursive
```

## Pipeline build (recommended)

The root `build.zig` orchestrates the full 3-tier DAG pipeline:

```sh
zig build pipeline             # full ordered build (default step)
zig build build-lib            # libnexus-engine.a only (Cherno engine core)
zig build build-runtime        # nexus-runtime (no editor)
zig build build-engine         # both T2 paths
zig build build-editor         # editor only (depends on build-lib)
zig build pipeline --summary all   # visualise the execution graph
```

Artifacts per tier:
- `engine/build/lib/libnexus-engine.a` — Nexus static library (Cherno engine core, no editor)
- `engine/build/bin/nexus-runtime` — no-editor runtime (ships without editor)
- `editor/build/bin/link-editor` — editor executable (separate consumer)

### Per-tier pipeline steps

Each submodule also exposes its own `pipeline` step for standalone use:

| Tier | Directory | Command | DAG |
|------|-----------|---------|-----|
| zGameLib (T1) | `engine/libs/zGameLib` | `cd engine/libs/zGameLib && zig build pipeline` | adapter libs → framework |
| Nexus-engine (T2) | `engine/` | `cd engine && zig build pipeline` | zGameLib → build-lib → build-runtime |
| Link-editor (T3) | `editor/` | `cd editor && zig build pipeline` | engine → editor binary |

### Hot reload strategy

The bundle uses a **hybrid** model (data reload first, selective native code reload in a shared lib, fast restart as fallback). The stable host is `libnexus-engine.a`; reloadable gameplay stays **out** of the static lib.

**Source of truth:** [`docs/hot-reload-theory.md`](docs/hot-reload-theory.md) — citations from Handmade Hero (Casey Muratori), Hazel/TheCherno asset reload, Madrigal Games Traction Point (Zig).

Tier-specific implementation: `engine/docs/theory/08-hot-reload-nexus-engine.md`, `engine/docs/theory/09-hot-reload-crucible.md`.

## Standalone build per tier (still works)

```sh
cd engine && zig build          # → engine/zig-out/lib/libnexus-engine.a
cd engine && zig build run      # runs nexus-runtime

cd editor && zig build          # → editor/zig-out/bin/link-editor
cd editor && zig build run
```

Requires Zig **0.16.0** (pinned in CI by `mlugg/setup-zig@v2`). Windows/macOS/Linux all in scope. `zig build run` needs a display + Vulkan loader; the CI `run` step will fail in a headless environment.

**Current build status**: full pipeline succeeds (`zig build pipeline`). Engine exports `NexusApp` from `src/root.zig`; editor links `libnexus-engine.a`.

## Key gotchas

- **No tests** anywhere. No `zig build test` step.
- **engine/AGENTS.md** contains engine-specific agent guidance — source of truth for that tier.
- **Root `README.md` is now up to date** — describes the 3-tier Cherno-aligned pipeline architecture.
- **Consumer hookup** — editor imports `nexus` module for types and `linkLibrary`s `libnexus-engine.a` (libs-first pattern).
- **Hot reload** — hybrid strategy documented in `docs/hot-reload-theory.md`; future `build-plugin` DAG step for reloadable shared lib (not implemented yet).
- **`build/` is gitignored** (standard Zig build output).
- **C/C++ dirs** (`src/c/`, `src/cpp/`) are template leftovers — **not compiled** by engine or editor builds.
