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

Follows TheCherno's recommended pattern: core engine as a **static library**, consumed by editor and future game executables.

```
T3: Link-editor (editor/)    — exe linking Nexus static lib
T2: Nexus Engine (engine/)   — static library (engine/build/lib/)
T1: zGameLib (engine/libs/)  — Zig modules (comptime-friendly)
```

Zig adaptation:
- **T1** uses `b.addModule` (source-level modules — where comptime shines)
- **T2** uses `b.addLibrary(.{ .linkage = .static })` (Cherno boundary)
- **T3** uses `b.addExecutable` + `linkLibrary` (consumer)

## Initial setup

```sh
git submodule update --init --recursive
```

## Pipeline build (recommended)

The root `build.zig` orchestrates the full 3-tier DAG pipeline:

```sh
zig build pipeline             # full ordered build (default step)
zig build build-engine         # Nexus static lib + runtime exe
zig build build-editor         # editor only
zig build pipeline --summary all   # visualise the execution graph
```

Artifacts per tier:
- `engine/build/lib/libnexus-engine.a` — Nexus static library (Cherno boundary)
- `engine/build/bin/nexus-runtime` — standalone test runner
- `editor/build/bin/link-editor` — editor consumer executable

### Per-tier pipeline steps

Each submodule also exposes its own `pipeline` step for standalone use:

| Tier | Directory | Command | DAG |
|------|-----------|---------|-----|
| zGameLib (T1) | `engine/libs/zGameLib` | `cd engine/libs/zGameLib && zig build pipeline` | adapter libs → framework |
| Nexus-engine (T2) | `engine/` | `cd engine && zig build pipeline` | zGameLib → Nexus static lib + runtime exe |
| Link-editor (T3) | `editor/` | `cd editor && zig build pipeline` | engine → editor binary |

## Standalone build per tier (still works)

```sh
cd engine && zig build          # → engine/zig-out/lib/libnexus-engine.a
cd engine && zig build run      # runs nexus-runtime

cd editor && zig build          # → editor/zig-out/bin/link-editor
cd editor && zig build run
```

Requires Zig **0.16.0** (pinned in CI by `mlugg/setup-zig@v2`). Windows/macOS/Linux all in scope. `zig build run` needs a display + Vulkan loader; the CI `run` step will fail in a headless environment.

**Current build status**: engine pipeline succeeds (`zig build pipeline`). Editor resolves its nexus-engine dependency but has a pre-existing compilation error in `src/main.zig` (`NexusApp` not yet exported by engine).

## Key gotchas

- **No tests** anywhere. No `zig build test` step.
- **engine/AGENTS.md** contains engine-specific agent guidance — source of truth for that tier.
- **Root `README.md` is now up to date** — describes the 3-tier Cherno-aligned pipeline architecture.
- **`build/` is gitignored** (standard Zig build output).
- **C/C++ dirs** (`src/c/`, `src/cpp/`) are template leftovers — **not compiled** by engine or editor builds.
