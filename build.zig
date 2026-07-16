const std = @import("std");

pub fn build(b: *std.Build) void {
    _ = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const optimize_flag = b.fmt("-Doptimize={s}", .{@tagName(optimize)});

    // ============================================================
    // Tier 2: Nexus-engine (T1 zGameLib is built as a dependency)
    // ============================================================
    const engine_cmd = b.addSystemCommand(&.{
        "zig", "build",
        "--prefix", "build",
        optimize_flag,
    });
    engine_cmd.setCwd(b.path("engine"));

    const engine_step = b.step("build-engine",
        "Build Nexus-engine (+ zGameLib) into engine/build/");
    engine_step.dependOn(&engine_cmd.step);

    // ============================================================
    // Tier 3: Link-editor (depends on engine contract)
    // ============================================================
    const editor_cmd = b.addSystemCommand(&.{
        "zig", "build",
        "--prefix", "build",
        optimize_flag,
    });
    editor_cmd.setCwd(b.path("editor"));

    const editor_step = b.step("build-editor",
        "Build Link-editor into editor/build/ (depends on engine)");
    editor_step.dependOn(&editor_cmd.step);

    // ============================================================
    // Top-level pipeline step — the "one command" entry point
    // ============================================================
    const pipeline_step = b.step("pipeline",
        \\Full 3-way-handshake pipeline: zGameLib → Nexus-engine → Link-editor
        \\
        \\  zig build pipeline               # full ordered build (default)
        \\  zig build build-engine           # engine (+ zGameLib) only
        \\  zig build build-editor           # editor only (no engine rebuild)
        \\
        \\Artifacts are installed per tier:
        \\  engine/build/bin/nexus-engine
        \\  editor/build/bin/link-editor
        \\
        \\Use --summary all to visualise the DAG:
        \\  zig build pipeline --summary all
    );
    pipeline_step.dependOn(engine_step);
    pipeline_step.dependOn(editor_step);

    b.default_step = pipeline_step;
}
