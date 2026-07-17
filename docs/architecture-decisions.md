# Architecture Decisions

> **Two hard-won technical decisions that now apply across the full stack.**

## 1. Library linking model: static engine + dynamic game logic

### Decision

| Layer | Form | Rationale |
|-------|------|-----------|
| **Engine core** (Nexus) | Static library `.a` / `.lib` | Stable host — never swapped |
| **Game logic** | Dynamic library `.so` / `.dll` | Hot-reloadable during development |
| **Final executable** | Statically links engine, loads game DLL at runtime | Clean separation of concerns |

The editor follows the same model: it links the static `libnexus-engine.a` through `plugins/` and will load game/tool logic as a shared library when the `build-plugin` DAG step lands.

### Supporting sources

#### TheCherno — engine as static library

TheCherno's Hazel series teaches a pattern where the core engine is a **static library** consumed by separate executables (Sandbox, Editor, game). The teaching is that a static library gives you the benefits of separate compilation units without the export/import boilerplate and ABI instability of DLLs during active development.

> "Separate out your core engine into its own static library and then just link that to all of your executables."
> — TheCherno, Hazel engine series (as commonly cited in the game-dev community)

Real-world reasoning behind the choice:
- DLL boundaries force a C ABI, losing Zig's slices, error unions, and generic types
- Static linking enables full Link-Time Optimization across the engine boundary
- Export/import macros and versioned symbol tables add friction with no benefit during early-to-mid development
- Hazel itself migrated toward this model after experiencing DLL complexity in earlier iterations

#### Casey Muratori — stable platform + DLL game code

Handmade Hero established the complementary pattern: the **platform/engine layer is static** and long-lived; the **game code lives in a DLL** that can be hot-reloaded. The platform owns all persistent memory; on reload it hands the same memory block to the new DLL.

> "You have a platform layer that allocates all the memory up front… then the game code is in a DLL. You pass the entire memory block into the game update function. When you recompile the DLL, you just reload it and keep passing the same memory pointer."
> — Casey Muratori, Handmade Hero Day 021

**Sources:**
- [Handmade Hero Day 021 — Loading Game Code Dynamically](https://guide.handmadehero.org/code/day021/)
- [Day 021 notes (yakvi)](https://yakvi.github.io/handmade-hero-notes/html/day21.html)

#### Madrigal Games — Zig gameplay on a C++ engine (hybrid DLL)

Sebastian Aaltonen's *Traction Point* engine uses a C++ host with Zig gameplay in a hot-reloadable DLL. Key practices that apply to our stack:

- Copy-to-unique-name before loading (`GameReload.dll`) to avoid OS file locks
- Host-owned allocators so Zig heap data survives the reload
- Explicit `beforeHotReload` / `afterHotReload` callbacks for pointer fixups

**Source:** [How I made my Zig gameplay code hot reloadable](https://www.madrigalgames.com/blog/how-i-made-my-zig-gameplay-code-hot-reloadable/) (May 2026)

### How this maps onto our stack

```
┌─────────────────────────────────────────────────────────┐
│  nexus-runtime / link-editor  (executable, links .a)    │
│  ├── libnexus-engine.a       (static — NEVER reloaded)  │
│  └── libgameplay.so          (dynamic — reloaded)       │
├─────────────────────────────────────────────────────────┤
│  EngineInterface: C-ABI boundary for editor ↔ engine    │
│  GameUpdate:     C-ABI entry for hot-reloadable DLL    │
└─────────────────────────────────────────────────────────┘
```

- `libnexus-engine.a` → built by `zig build build-lib` (engine core — no editor, no gameplay)
- Game DLL (future `build-plugin` step) → reloadable gameplay code
- The Nexus **static library never contains game logic** — that is the rule that makes hot reload possible

**Detailed implementation path:** [`docs/hot-reload-theory.md`](hot-reload-theory.md) (hybrid reload strategy) · [`docs/static_lib_caveat.txt`](static_lib_caveat.txt) (build paths)

---

## 2. Script encapsulation for CI and local development

### Decision

> **No non-trivial Python or bash logic may live inline inside `.github/workflows/*.yml`.**

All meaningful scripts must be placed under `scripts/` and called from the workflow. The same scripts must be usable both locally and inside the Docker-based build environment.

### Why this rule exists

| Problem | How inline YAML makes it worse | How `scripts/` fixes it |
|---------|-------------------------------|------------------------|
| **Readability** | YAML concatenation, escaping, and multi-line strings obscure intent | A `.sh` file is a plain program |
| **Testability** | You can only run inline logic by triggering CI | Scripts run locally with `bash script.sh` |
| **Portability** | Inline scripts don't exist inside the Docker container unless duplicated | The Docker entrypoint invokes the same `scripts/` files |
| **Reviewability** | A 40-line `run:` block is harder to review than a one-line `run: bash scripts/check.sh` | PRs show a single command call |
| **Drift** | CI YAML and local workflows diverge because there's no shared source of truth | One script, two callers — no drift |

### The rule in practice

```yaml
# ✅ Good — script encapsulates logic
- name: CI checks
  run: bash scripts/ci.sh check

# ❌ Bad — logic inlined in YAML
- name: CI checks
  run: |
    if [ -f "some_file" ]; then
      while read -r line; do
        echo "$line" | grep -q "pattern" || exit 1
      done < "some_file"
    fi
```

### Enforcement

- Workflow reviews should flag inline `run:` blocks longer than ~5 lines
- The `scripts/` directory is the single source of truth for build, test, and CI logic
- Docker containers use the same scripts (mounted at `/workspace/scripts/`)
- Each component (zGameLib, Nexus-engine, Link-editor, root) follows this pattern independently

### Precedent in this repo

| Component | Script | Used by CI | Used by Docker |
|-----------|--------|-----------|----------------|
| zGameLib | `scripts/ci.sh check` | `.github/workflows/build.yml` | `docker/Dockerfile` (via `build-in-docker.sh`) |
| All tiers | `scripts/build-in-docker.sh` | (CI uses Zig directly) | `docker/Dockerfile` as ENTRYPOINT |
| All tiers | `scripts/clean.sh` | — | Local cleanup |
| Root | `scripts/build-full-stack-in-docker.sh` | `.github/workflows/ci.yml` | `docker/Dockerfile` entrypoint |

---

## References

| Document | What it covers |
|----------|----------------|
| [`docs/hot-reload-theory.md`](hot-reload-theory.md) | Full hybrid reload strategy with Tier-specific implementation notes |
| [`docs/static_lib_caveat.txt`](static_lib_caveat.txt) | Build paths for the static library + runtime split |
| [`contract/engine_interface.zig`](../contract/engine_interface.zig) | The EngineInterface vtable contract |
| [`AGENTS.md`](../AGENTS.md) | Agent-accessible summaries of the architecture |
