#!/usr/bin/env bash
# Build ZMK firmware locally using Docker. First run initializes ~/zmk-workspace
# (~700 MB of west modules); subsequent runs reuse it and are much faster.
set -euo pipefail

CONFIG_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${ZMK_WORKSPACE:-$HOME/zmk-workspace}"
OUT_DIR="$CONFIG_DIR/firmware"
IMAGE="zmkfirmware/zmk-build-arm:stable"

mkdir -p "$WORKSPACE" "$OUT_DIR"

INIT_CMD=""
if [ ! -d "$WORKSPACE/.west" ]; then
  echo ">> First run — initializing west workspace (downloads ~700 MB of modules)"
  INIT_CMD="west init -l /workspaces/zmk/config && west update && west zephyr-export && "
fi

docker run --rm \
  --mount type=bind,source="$WORKSPACE",target=/workspaces/zmk \
  --mount type=bind,source="$CONFIG_DIR/config",target=/workspaces/zmk/config,readonly \
  --mount type=bind,source="$OUT_DIR",target=/firmware \
  -w /workspaces/zmk \
  "$IMAGE" \
  bash -c "
    set -e
    ${INIT_CMD}
    west build -p -s zmk/app -d build/left  -b nice_nano_v2 -- -DSHIELD=corne_left     -DZMK_CONFIG=/workspaces/zmk/config
    west build -p -s zmk/app -d build/right -b nice_nano_v2 -- -DSHIELD=corne_right    -DZMK_CONFIG=/workspaces/zmk/config
    west build -p -s zmk/app -d build/reset -b nice_nano_v2 -- -DSHIELD=settings_reset -DZMK_CONFIG=/workspaces/zmk/config
    cp build/left/zephyr/zmk.uf2  /firmware/corne_left-nice_nano_v2.uf2
    cp build/right/zephyr/zmk.uf2 /firmware/corne_right-nice_nano_v2.uf2
    cp build/reset/zephyr/zmk.uf2 /firmware/settings_reset-nice_nano_v2.uf2
  "

echo
echo ">> Done. Firmware:"
ls -lh "$OUT_DIR"/*.uf2
