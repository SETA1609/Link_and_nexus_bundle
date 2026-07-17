#!/usr/bin/env bash
# Build the full 3-tier stack inside Docker.
# Orchestrates: zGameLib (T1) → Nexus-engine (T2) → Link-editor (T3)
# Usage: ./scripts/build-full-stack-in-docker.sh [step]
#   step: pipeline (default), build-lib, build-engine, build-editor, or any zig build step
set -euo pipefail

STEP="${1:-pipeline}"

cd "$(dirname "$0")/.."

git submodule update --init --recursive

echo "==> Root bundle: zig build ${STEP}"
zig build "${STEP}"
