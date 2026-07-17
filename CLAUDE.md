# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A **meta-repository (bundle)** that aggregates three architectural tiers via Git submodules. The real code lives in the submodules — this root only owns the pipeline orchestrator, the `EngineInterface` contract, shared docs, and CI/Docker wiring.

| Tier | Repo | Submodule path | Role |
|------|------|----------------|------|
| T1 — zGameLib | `SETA1609/zGameLib` | `engine/libs/zGameLib` (nested) | Zig modules: platform, Vulkan, GPU, FrameRing |
| T2 — Nexus Engine | `SETA1609/Nexus-engine` | `engine/` | Static library `libnexus-engine.a` + no-editor runtime |
| T3 — Link-editor | `SETA1609/Link-editor` | `editor/` | Editor executable that links the engine `.a` |

**Per-tier source of truth:** each submodule has its own `AGENTS.md` (`engine/AGENTS.md`, `editor/AGENTS.md`, `engine/libs/zGameLib/AGENTS.md`). Consult the relevant one before working inside a tier. The root `AGENTS.md` is the fullest version of this file.

## Setup

```sh
git submodule update --init --recursive   # required before any build
```

Requires **Zig 0.16.0** (pinned in CI via `mlugg/setup-zig@v2`). `zig build run` needs a display + Vulkan loader, so it fails in headless/CI environments.

## Build commands

The root `build.zig` orchestrates the full 3-tier DAG. Each step shells out to the submodule builds with `--prefix build`.

```sh
zig build pipeline              # full ordered build (default step)
zig build build-lib            # T2: libnexus-engine.a only (engine core, no editor)
zig build build-runtime        # T2: nexus-runtime (no-editor consumer)
zig build build-engine         # T2: lib + runtime
zig build build-editor         # T3: editor (depends on build-lib → install-plugin)
zig build install-plugin       # copy engine .a → editor/plugins/
zig build pipeline --summary all   # visualise the execution graph
```

Artifacts:
- `engine/build/lib/libnexus-engine.a` — static engine core
- `engine/build/bin/nexus-runtime` — runtime without editor
- `editor/build/bin/link-editor` — editor executable

Standalone per-tier builds still work (`cd engine && zig build`, `cd editor && zig build`, each also exposing its own `pipeline` step).

## Architecture (Cherno static-library model)

Follows TheCherno's Hazel pattern: the engine core is a **static library**; editor and runtime are separate consumers that link it.

- **T1 (zGameLib)** stays as source-level Zig modules (`b.addModule`) — this is where comptime generics / zero-overhead abstractions matter.
- **T2 (Nexus)** builds `libnexus-engine.a` from `engine/src/root.zig` (exports `NexusApp`) plus a thin `nexus-runtime` from `engine/src/runtime/main.zig`.
- **T3 (editor)** does **not** depend on engine source. It imports the `engine_interface` module for types and links the prebuilt `.a` from `editor/plugins/` — which the root pipeline populates via `install-plugin`.

### EngineInterface contract

The root owns `contract/engine_interface.zig` — a vtable-based interface (`EngineInterface` + `VTable`) that decouples the editor from any specific engine. Both `engine/` and `editor/` reference it via `b.path("../contract/engine_interface.zig")`.

- Nexus implements the vtable and exposes a `createEngineInterface()` factory (extern symbol).
- The editor consumes any engine through the factory + interface — swap engines by supplying a different factory.
- Engine-specific features (Flecs, SceneNode, hot-reload) are gated behind optional capability flags / `getNexusApi`, so alternative engines leave them null.

### Hot reload

Hybrid strategy (data reload first → selective native code reload in a shared lib → fast restart fallback). `libnexus-engine.a` is the stable host; reloadable gameplay stays out of the static lib. Theory: `docs/hot-reload-theory.md`; the `build-plugin` DAG step is not implemented yet.

## Docker / CI

- Root: `./scripts/build-full-stack-in-docker.sh [step]` (defaults to `pipeline`); `./scripts/clean.sh` to clean. Each tier has its own `docker/Dockerfile` + `scripts/{build-in-docker,shell,clean}.sh` (Ubuntu 24.04 + Zig 0.16.0 + Vulkan ICD).
- CI (`.github/workflows/ci.yml`) runs the tiers sequentially (zgame → nexus → editor → full-stack) via the reusable `reusable/build.yml`, which parameterizes component/target/os.

## Gotchas

- **No tests anywhere** — there is no `zig build test` step in any tier.
- **Root `src/` (`src/main.zig`, `src/c/`, `src/cpp/`) is a stale cpp-zig-hybrid template** — it is NOT compiled by the engine or editor builds. Ignore it for architecture.
- **`build/` is gitignored** (Zig build output prefix used by the pipeline).
- The editor links the engine through `editor/plugins/libnexus-engine.a`; if the editor build fails with a missing symbol, ensure `install-plugin` (or the full `pipeline`) ran first.
