// Pipeline orchestrator for the Link & Nexus 3-tier stack.
// Architecture follows TheCherno's recommended model (Hazel series):
//   "Separate out your core engine into its own static library and then
//    just link that to all of your executables."
//
//   T1: zGameLib — Zig modules (source-level, comptime-friendly)
//   T2: Nexus    — STATIC LIBRARY (Cherno boundary: engine/build/lib/)
//   T3: Editor   — executable that links the Nexus library
//                  (+ future games/runtimes as additional consumers)
//
// Zig's adaptation: zGameLib stays as modules (where Zig's comptime
// shines), Nexus is a .a/.lib for the explicit contract, consumers
// are executables. This gives clean separation, faster editor iteration,
// and a professional "engine as product" workflow.

const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const optimize_flag = b.fmt("-Doptimize={s}", .{@tagName(optimize)});

    // ============================================================
    // T2: Nexus-engine — primary artifact is a STATIC LIBRARY
    //     (zGameLib T1 is built transitively as a Zig dependency)
    // ============================================================
    const engine_cmd = b.addSystemCommand(&.{
        "zig", "build",
        "--prefix", "build",
        optimize_flag,
    });
    engine_cmd.setCwd(b.path("engine"));

    const engine_step = b.step("build-engine",
        "Build Nexus static library (primary) + runtime exe (testing)");
    engine_step.dependOn(&engine_cmd.step);

    // ============================================================
    // T3: Link-editor — executable consuming the Nexus library
    // ============================================================
    const editor_cmd = b.addSystemCommand(&.{
        "zig", "build",
        "--prefix", "build",
        optimize_flag,
    });
    editor_cmd.setCwd(b.path("editor"));

    const editor_step = b.step("build-editor",
        "Build Link-editor (links Nexus static lib) → editor/build/bin/");
    editor_step.dependOn(&editor_cmd.step);

    // ============================================================
    // Pipeline — the one-command entry point
    // ============================================================
    const pipeline_step = b.step("pipeline",
        \\Full 3-tier pipeline: zGameLib (modules) → Nexus (static lib) → Editor (consumer)
        \\
        \\  zig build pipeline                 # full ordered build (default)
        \\  zig build build-engine             # Nexus static lib + runtime exe
        \\  zig build build-editor             # Link-editor only
        \\  zig build pipeline --summary all   # visualise the DAG
        \\
        \\Artifacts (Cherno model):
        \\  engine/build/lib/libnexus-engine.a   — core engine (static lib)
        \\  engine/build/bin/nexus-runtime       — standalone test runner
        \\  editor/build/bin/link-editor          — editor consumer exe
    );
    pipeline_step.dependOn(engine_step);
    pipeline_step.dependOn(editor_step);

    b.default_step = pipeline_step;
}
