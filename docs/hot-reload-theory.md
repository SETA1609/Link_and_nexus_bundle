# Hybrid Hot Reload — Theory & Citations

> **Author:** SETA1609  
> **Scope:** Contract documentation for the `Link_and_nexus_bundle` meta-repository.  
> **Status:** Architectural decision record — implementation follows in tier-specific roadmaps.

This document explains *why* the Link & Nexus stack adopts a **hybrid hot-reload strategy** (data-driven reloading plus selective native code reloading) instead of pure every-frame DLL swapping or relying solely on fast restarts. It ties that decision to the existing Cherno-style build DAG and the three-tier submodule layout.

**Related build docs:** [`README.md`](../README.md) (pipeline + artifacts) · [`AGENTS.md`](../AGENTS.md) (agent guidance) · [`static_lib_caveat.txt`](static_lib_caveat.txt) (Cherno static-lib paths)

---

## The problem we are solving

Game engine iteration speed depends on how quickly a running process can absorb changes. Three common strategies each fail in isolation:

| Approach | Strength | Weakness |
|----------|----------|----------|
| **Pure code hot reload** (reload a shared library every change) | Powerful for logic tweaks while state is live | Fragile: stale function pointers, layout changes, threading sync, OS file locks |
| **Pure data hot reload** (watch files, patch assets/scenes) | Safe, fast, designer-friendly | Cannot change gameplay algorithms without a restart |
| **Fast full restart** | Simple, always correct | Loses in-memory state; painful for rare, hard-to-reproduce bugs |

The bundle adopts a **hybrid**: prioritize data reload, add **controlled** code reload for gameplay/editor-plugin layers, and keep **fast restart** as an honest fallback — especially while Zig compile times are still improving.

---

## Why a hybrid approach?

### Casey Muratori — stable platform + reloadable game code

Handmade Hero **Day 021 — Loading Game Code Dynamically** separates a long-lived **platform layer** (executable) from **game code** compiled into a dynamically loaded library. The platform owns persistent memory; the game DLL receives a pointer to that memory on each update. When the DLL is recompiled, the platform unloads the old library, loads the new one, and passes the **same memory block** — the game continues with preserved state.

Summarizing the pattern Casey establishes in that episode:

> "You have a platform layer that allocates all the memory up front… then the game code is in a DLL. You pass the entire memory block into the game update function. When you recompile the DLL, you just reload it and keep passing the same memory pointer."

**Primary source:** [Handmade Hero Day 021 — Loading Game Code Dynamically](https://guide.handmadehero.org/code/day021/) (indexed guide; episode on [hero.handmade.network](https://hero.handmade.network/)).

Indexer notes on the same episode capture the mechanism in more detail:

> "Our platform layer reserves the memory and passes the whole chunk to the game. When the game is done doing its work, the memory is preserved for the main loop's next iteration. This allows us to unload the game, swap the game code with the new version, and give it the memory the previous guy was using."

**Supplementary:** [Handmade Hero Day 021 notes (yakvi)](https://yakvi.github.io/handmade-hero-notes/html/day21.html)

**Lesson for this stack:** Nexus (`libnexus-engine.a`) is the **stable host** — memory arenas, Flecs world, Vulkan/device lifetime, main loop. Reloadable gameplay and tool logic live **outside** that boundary in a shared library, not inside the static lib.

### Madrigal Games — practical Zig reload on a C++ engine

Sebastian Aaltonen's [*How I made my Zig gameplay code hot reloadable*](https://www.madrigalgames.com/blog/how-i-made-my-zig-gameplay-code-hot-reloadable/) (May 2026) documents **Traction Point**: a mature C++ engine host with Zig gameplay in a separate DLL. The post is the closest public Zig precedent for our model.

On loading/unloading:

> "Rather than loading the game library directly, it copies the lib to a new file with a distinct name (eg. `GameReload.dll` instead of `Game.dll`) and loads that."

The article also covers: thread sync points before unload, **host-owned allocators** so Zig heap survives reload, explicit `beforeHotReload` / `afterHotReload` callback rewiring, and vtable fixups for runtime interfaces.

**Lesson for this stack:** Copy-to-unique-name avoids OS file locks; persistent state lives in **host memory**, not in DLL globals; function pointers must be **re-bound** after every reload.

### TheCherno / Hazel — data reload complements code reload

TheCherno's Hazel series emphasizes **editor/runtime separation** (engine as library, editor as consumer) and **asset iteration** without restarting the whole toolchain.

From [Hazel 2024.1 release notes](https://docs.hazelengine.com/HazelReleaseNotes/Hazel-2024.1.html) (async asset system):

> "Automatic hot-reloading of assets which have changed on disk, thanks to the asset monitoring system running on the background asset thread."

Workflow context: [*From Editor to Runtime — The Hazel Engine Workflow*](https://www.youtube.com/watch?v=Z2U-S3fxAg8) — edit in Hazelnut, run in the runtime without shipping editor code.

**Lesson for this stack:** **Data reload is not a consolation prize** — it is the daily driver for artists and designers. Native code reload is for programmers tuning logic while state is frozen in the host — the same division Hazel uses between asset thread monitoring and compiled engine/editor binaries.

### Unity-style influence (data-driven layer)

Commercial engines (Unity among them) popularized **asset and scene reloading** independent of managed/native code domains. Our data layer follows that philosophy: if a change is expressible as files on disk (textures, scenes, `.po` locale, WASM mod packages), reload it through `ResourceDB` + `ReloadEventBus` without touching code. See [`engine/docs/theory/08-hot-reload-nexus-engine.md`](../engine/docs/theory/08-hot-reload-nexus-engine.md) for tier-specific event design.

---

## Recommended hybrid model for this stack

Three layers map cleanly onto zGameLib (T1), Nexus (T2), and Link-editor (T3):

```ascii
┌─────────────────────────────────────────────────────────────────────┐
│  LAYER 3 — Data-driven reload                                       │
│    Scenes · prefabs · textures · locale · WASM mod assets           │
│    File watcher → ResourceDB / Flecs patch → ReloadEventBus         │
│    (Unity-style asset iteration + Nexus v0.9.0+ roadmap)          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ reads/writes host-owned state
┌───────────────────────────────▼─────────────────────────────────────┐
│  LAYER 2 — Reloadable game / tool code (shared library)             │
│    Gameplay systems · editor tool plugins · mod scripting glue      │
│    Copy-on-load DLL/.so · GameUpdate(&persistent_state) entry      │
│    (Casey DLL model + Traction Point Zig practice)                  │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ imports API + linkLibrary
┌───────────────────────────────▼─────────────────────────────────────┐
│  LAYER 1 — Stable host (Nexus static library)                       │
│    libnexus-engine.a — arenas, Flecs world, Vulkan, NexusApp loop   │
│    nexus-runtime exe — ships without editor (Cherno Hazel core)     │
│    NO editor ImGui · NO reloadable gameplay in the .a itself          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │ zgame modules
┌───────────────────────────────▼─────────────────────────────────────┐
│  T1 — zGameLib (modules)                                            │
│    Platform · GPU · FrameRing — comptime-friendly foundation        │
└─────────────────────────────────────────────────────────────────────┘
```

### Layer 1 — Stable host (`libnexus-engine.a`)

- Built by `zig build build-lib` → `engine/build/lib/libnexus-engine.a`
- Public API in `engine/src/root.zig` (`NexusApp`, servers, `ReloadEventBus`, …)
- Owns **all long-lived state**: allocators, GPU devices, ECS world, scene roots
- **No editor code** — matches Cherno's rule that runtime ships without Hazelnut

### Layer 2 — Reloadable game layer (future `build-plugin`)

- Gameplay and selective **editor tool code** compiled as a **shared library** (`.so` / `.dll`)
- Entry point receives `*PersistentState` owned by Layer 1 (Casey `game_memory` pattern)
- Load via copy-to-unique-path (Traction Point `GameReload.dll` pattern)
- Planned as a future DAG step (e.g. `build-plugin` or `hot-reload`) — **not implemented in this contract repo yet**

### Layer 3 — Data-driven layer

- Independent of code reload: file watcher → invalidate → re-upload / re-parse
- Flecs component **values** and scene files reload without recompiling Zig
- Editor (T3) drives reimport via `EditorHost` when Crucible ships (v1.1.0+)
- Roadmap: Nexus v0.9.0 `ReloadEventBus`, v1.2.0 locale reload — see [`ROADMAP.md`](../ROADMAP.md)

---

## How it integrates with the existing architecture

### Root build DAG

The meta-repo [`build.zig`](../build.zig) orchestrates tiers with per-component `--prefix build` output:

| Step | Produces | Role in hot reload |
|------|----------|-------------------|
| `build-lib` | `engine/build/lib/libnexus-engine.a` | **Stable host** — never swapped at runtime |
| `build-runtime` | `engine/build/bin/nexus-runtime` | No-editor consumer (Cherno runtime) |
| `build-editor` | `editor/build/bin/link-editor` | Editor consumer — separate exe, same static lib |
| *(future)* `build-plugin` | `engine/build/bin/libnexus_game.so` (name TBD) | Reloadable gameplay layer |

```bash
zig build pipeline          # full stack today
zig build build-lib         # host only — required before any consumer links
zig build build-runtime     # verify runtime without editor
zig build build-editor      # editor path (depends on build-lib)
```

### Cherno separation preserved

- **Hazel** = `libnexus-engine.a` + `nexus-runtime` (no editor)
- **Hazelnut** = `link-editor` (ImGui, panels, file watcher UI)
- **Game DLL** = future shared lib for reloadable logic — neither Hazel nor Hazelnut

Consumers use the libs-first Zig pattern:

```zig
consumer_mod.addImport("nexus", nexus_dep.module("nexus"));
consumer_mod.linkLibrary(nexus_dep.artifact("nexus-engine"));
```

### Tier documentation map

| Tier | Hot-reload responsibility | Deep dive |
|------|---------------------------|-----------|
| **T1 zGameLib** | GPU re-upload primitives, optional file-watch helpers | `engine/libs/zGameLib/docs/theory/` |
| **T2 Nexus** | `ReloadEventBus`, `ResourceDB`, Flecs patches | [`engine/docs/theory/08-hot-reload-nexus-engine.md`](../engine/docs/theory/08-hot-reload-nexus-engine.md) |
| **T3 Link-editor** | File watcher UI, `EditorHost.reimport`, play-in-editor | [`engine/docs/theory/09-hot-reload-crucible.md`](../engine/docs/theory/09-hot-reload-crucible.md) |

---

## Practical trade-offs (objective view)

### Prioritize data reload first

- **Fast and safe** — no function-pointer surgery, no DLL unload races
- Aligns with Hazel's asset-thread monitoring and our `ReloadEventBus` roadmap
- Delivers value to the whole team before any native code swapping exists

### Add code reload selectively

- **High power** for programmers: tune feel, debug rare states, iterate ImGui tooling (Traction Point's primary wins)
- **Costs:** host-owned allocators only, no layout changes across reload, sync points if worker threads touch game code, copy-rename load discipline
- **Scope:** gameplay + tool plugins in the shared lib — **not** the Nexus static lib itself

### Fast full restart remains valid

- Zig compile times are improving ([incremental compilation in 0.16](https://ziglang.org/download/0.16.0/release-notes.html#Incremental-Compilation)) but are not yet "instant" on all platforms (Traction Point notes LLVM backend latency on Windows)
- Restart is correct when structs change shape, host APIs change, or reload safety checks fail
- Cheap restarts are a feature, not an admission of failure

### WASM modding as a third reload channel

Post–v1.0.0, sandboxed `.wasm` mods reload through `WasmHost` — orthogonal to native DLL reload. See [`engine/docs/theory/13-wasm-modding.md`](../engine/docs/theory/13-wasm-modding.md).

---

## High-level implementation outline (future work)

This section is intentionally **not** a full implementation guide — code lands in follow-up PRs per tier.

1. **Host state block** — `NexusContext` exposes a single `PersistentState` region (arenas + handles), passed into `game_update(state, input, dt)`.
2. **Plugin build step** — `build-plugin` produces a shared lib; install to `engine/build/bin/` with versioned copy for reload.
3. **Loader in `nexus-runtime`** — file watcher on the compiler output; sync point in `NexusApp.tick`; copy → `dlopen` / `LoadLibrary` → resolve entry → call `before_reload` / `after_reload`.
4. **Data path (parallel)** — `ReloadEventBus.publish(.resource | .scene | .locale)` without unloading any library.
5. **Editor path** — Crucible file watcher calls `EditorHost.reimport`; play-in-editor uses scene fork (no reload of host lib).
6. **Safety** — if reload fails, log and keep previous DLL; if state layout version mismatches, force restart.

**Optional tooling:** community experiments such as [`zr` on Ziggit](https://ziggit.dev/t/zr-simple-batteries-included-hot-reloading-for-zig/14019) — evaluate against our host-owned-state requirements before adoption.

---

## References

| Source | Link | What we take from it |
|--------|------|---------------------|
| Casey Muratori — Handmade Hero Day 021 | [guide.handmadehero.org/code/day021/](https://guide.handmadehero.org/code/day021/) | Platform owns memory; game in reloadable DLL |
| Casey Muratori — Day 021 notes | [yakvi.github.io/.../day21.html](https://yakvi.github.io/handmade-hero-notes/html/day21.html) | Persistent memory chunk across unload/reload |
| Madrigal Games — Traction Point (May 2026) | [madrigalgames.com blog](https://www.madrigalgames.com/blog/how-i-made-my-zig-gameplay-code-hot-reloadable/) | Copy-rename load, host allocators, callback rewiring |
| TheCherno — Hazel 2024.1 assets | [Hazel release notes](https://docs.hazelengine.com/HazelReleaseNotes/Hazel-2024.1.html) | Automatic on-disk asset hot reload |
| TheCherno — Editor/runtime workflow | [YouTube — Feb 2024](https://www.youtube.com/watch?v=Z2U-S3fxAg8) | Hazelnut vs runtime separation |
| TheCherno — Engine as static library | [Hazel repo](https://github.com/TheCherno/Hazel) · bundle [`README.md`](../README.md) | `libnexus-engine.a` Cherno boundary |
| Nexus engine reload design | [`08-hot-reload-nexus-engine.md`](../engine/docs/theory/08-hot-reload-nexus-engine.md) | `ReloadEventBus`, resource/scene phases |
| Crucible reload design | [`09-hot-reload-crucible.md`](../engine/docs/theory/09-hot-reload-crucible.md) | Editor-driven reimport |

---

*This document is the bundle-level source of truth for hot-reload **strategy**. Tier submodules own implementation milestones and API detail.*