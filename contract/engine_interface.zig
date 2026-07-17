//! EngineInterface — the contract between Link-editor and any game engine.
//!
//! The editor (Link-editor) depends on this interface instead of importing
//! Nexus modules directly. Engines (Nexus, or future alternatives) implement
//! the vtable and provide a factory function.
//!
//! Nexus-specific features (Flecs, SceneNode, hot-reload) are available through
//! optional capability flags and the optional `getNexusApi` pointer — engines
//! that don't support them simply leave those fields null/false.

const std = @import("std");

pub const EngineOptions = struct {
    title: [:0]const u8 = "Link-editor",
    width: u32 = 1280,
    height: u32 = 720,
};

pub const VTable = struct {
    init: *const fn (ctx: *anyopaque, opts: EngineOptions) anyerror!void,
    deinit: *const fn (ctx: *anyopaque) void,
    tick: *const fn (ctx: *anyopaque) anyerror!void,
    shouldClose: *const fn (ctx: *anyopaque) bool,
    getEngineName: *const fn (ctx: *anyopaque) []const u8,
    getEngineVersion: *const fn (ctx: *anyopaque) u32,
};

pub const EngineFactory = *const fn () EngineInterface;

pub const EngineInterface = struct {
    ctx: *anyopaque,
    vtable: *const VTable,

    pub fn wrap(ctx: *anyopaque, vtable: *const VTable) EngineInterface {
        return .{ .ctx = ctx, .vtable = vtable };
    }

    pub fn init(self: *EngineInterface, opts: EngineOptions) !void {
        return self.vtable.init(self.ctx, opts);
    }
    pub fn deinit(self: *EngineInterface) void {
        self.vtable.deinit(self.ctx);
    }
    pub fn tick(self: *EngineInterface) !void {
        return self.vtable.tick(self.ctx);
    }
    pub fn shouldClose(self: *const EngineInterface) bool {
        return self.vtable.shouldClose(self.ctx);
    }
    pub fn getEngineName(self: *const EngineInterface) []const u8 {
        return self.vtable.getEngineName(self.ctx);
    }
    pub fn getEngineVersion(self: *const EngineInterface) u32 {
        return self.vtable.getEngineVersion(self.ctx);
    }
};
