// Pipeline orchestrator for the Link & Nexus 3-tier stack.
// Architecture follows TheCherno's recommended model (Hazel series):
//   "Separate out your core engine into its own static library and then
//    just link that to all of your executables."
//
//   T1: zGameLib — Zig modules (source-level, comptime-friendly)
//   T2: Nexus    — STATIC LIBRARY + no-editor runtime (engine/build/)
//   T3: Editor   — separate executable linking libnexus-engine.a
//
// Cherno split on T2:
//   build-lib     → libnexus-engine.a  (Hazel — engine core, no editor)
//   build-runtime → nexus-runtime      (game/runtime without Hazelnut)

const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const optimize_flag = b.fmt("-Doptimize={s}", .{@tagName(optimize)});

    // ============================================================
    // T2 PATH 1: Nexus static library (Cherno engine core)
    // ============================================================
    const lib_cmd = b.addSystemCommand(&.{
        "zig", "build", "build-lib",
        "--prefix", "build",
        optimize_flag,
    });
    lib_cmd.setCwd(b.path("engine"));

    const lib_step = b.step("build-lib",
        "Build libnexus-engine.a (Cherno engine core — no editor)");
    lib_step.dependOn(&lib_cmd.step);

    // ============================================================
    // T2 PATH 2: No-editor runtime (Cherno game without editor)
    // ============================================================
    const runtime_cmd = b.addSystemCommand(&.{
        "zig", "build", "build-runtime",
        "--prefix", "build",
        optimize_flag,
    });
    runtime_cmd.setCwd(b.path("engine"));

    const runtime_step = b.step("build-runtime",
        "Build nexus-runtime (no-editor consumer of libnexus-engine.a)");
    runtime_step.dependOn(lib_step);
    runtime_step.dependOn(&runtime_cmd.step);

    // ============================================================
    // T2 aggregate: static lib + no-editor runtime
    // ============================================================
    const engine_step = b.step("build-engine",
        "Build Nexus: libnexus-engine.a + nexus-runtime");
    engine_step.dependOn(lib_step);
    engine_step.dependOn(runtime_step);

    // ============================================================
    // Install engine plugin into editor/plugins/ so the editor can
    // link the .a without a direct source dependency on the engine.
    // ============================================================
    const install_plugin = b.addSystemCommand(&.{
        "cp",
        "engine/build/lib/libnexus-engine.a",
        "editor/plugins/libnexus-engine.a",
    });
    const install_plugin_step = b.step("install-plugin",
        "Copy libnexus-engine.a → editor/plugins/");
    install_plugin_step.dependOn(lib_step);
    install_plugin_step.dependOn(&install_plugin.step);

    // ============================================================
    // T3: Link-editor — separate executable (Cherno Hazelnut)
    //     Links the .a from plugins/ — no direct engine dep.
    // ============================================================
    const editor_cmd = b.addSystemCommand(&.{
        "zig", "build",
        "--prefix", "build",
        optimize_flag,
    });
    editor_cmd.setCwd(b.path("editor"));

    const editor_step = b.step("build-editor",
        "Build Link-editor (links libnexus-engine.a) → editor/build/bin/");
    editor_step.dependOn(install_plugin_step);
    editor_step.dependOn(&editor_cmd.step);

    // ============================================================
    // Pipeline — full 3-tier DAG
    // ============================================================
    const pipeline_step = b.step("pipeline",
        \\Full 3-tier pipeline (Cherno model)
        \\
        \\  zig build build-lib       # T2: libnexus-engine.a only
        \\  zig build build-runtime   # T2: nexus-runtime (no editor)
        \\  zig build build-engine    # T2: lib + runtime
        \\  zig build build-editor    # T3: link-editor
        \\  zig build pipeline        # all of the above
        \\  zig build pipeline --summary all
        \\
        \\Artifacts:
        \\  engine/build/lib/libnexus-engine.a  — engine core (static lib)
        \\  engine/build/bin/nexus-runtime        — runtime without editor
        \\  editor/build/bin/link-editor           — editor (separate exe)
    );
    pipeline_step.dependOn(lib_step);
    pipeline_step.dependOn(runtime_step);
    pipeline_step.dependOn(editor_step);

    b.default_step = pipeline_step;
}