#!/usr/bin/env bash
# Clean up Docker resources and build artifacts across the full stack.
set -euo pipefail

source_dir="$(dirname "$0")/.."

echo "==> Removing root bundle Docker volumes and dangling images..."
docker image prune -f --filter "label=component=link-nexus-bundle" 2>/dev/null || true

# Root bundle artifacts
rm -rf "${source_dir}/.zig-cache" "${source_dir}/zig-out" "${source_dir}/build" "${source_dir}/zig-pkg" 2>/dev/null || true

# Submodule artifacts
rm -rf "${source_dir}/engine/.zig-cache" "${source_dir}/engine/zig-out" "${source_dir}/engine/build" "${source_dir}/engine/zig-pkg" 2>/dev/null || true
rm -rf "${source_dir}/editor/.zig-cache" "${source_dir}/editor/zig-out" "${source_dir}/editor/build" "${source_dir}/editor/zig-pkg" 2>/dev/null || true
rm -rf "${source_dir}/engine/libs/zGameLib/.zig-cache" "${source_dir}/engine/libs/zGameLib/zig-out" "${source_dir}/engine/libs/zGameLib/build" 2>/dev/null || true

echo "==> Done."
