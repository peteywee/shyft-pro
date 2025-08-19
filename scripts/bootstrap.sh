#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="time-mvp"

# create root only if missing
if [ ! -d "$ROOT_DIR" ]; then
  mkdir "$ROOT_DIR"
fi

cd "$ROOT_DIR"

# apps/api
if [ ! -d "apps/api" ]; then
  mkdir -p apps/api/src
  # … only then write files
fi

# apps/web
if [ ! -d "apps/web" ]; then
  mkdir -p apps/web
  # … run vite init here
fi

# packages/shared
if [ ! -d "packages/shared" ]; then
  mkdir -p packages/shared
fi
