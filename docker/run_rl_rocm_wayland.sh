#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-${IMAGE_NAME:-rocm6.3.4ub20}}"
CONTAINER_NAME="${2:-${CONTAINER_NAME:-rocm6.3.4ub20}}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-/home/tu/Documents/cpp_project/rl_rocm}"

if [[ "$IMAGE_NAME" == "-h" || "$IMAGE_NAME" == "--help" ]]; then
    echo "Usage: $0 [image_name[:tag]] [container_name]"
    echo
    echo "Examples:"
    echo "  $0"
    echo "  $0 my_rocm:latest my_rocm_container"
    echo "  IMAGE_NAME=my_rocm:latest CONTAINER_NAME=my_rocm_container $0"
    exit 0
fi

DOCKER_DEVICES=(
    --device /dev/kfd
    --device /dev/dri
    --device /dev/input
)

WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}"
HOST_XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
HOST_WAYLAND_SOCKET="${HOST_XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"

if [[ ! -S "$HOST_WAYLAND_SOCKET" ]]; then
    echo "Wayland socket not found: $HOST_WAYLAND_SOCKET" >&2
    echo "Set WAYLAND_DISPLAY and XDG_RUNTIME_DIR, then run this script from a Wayland session." >&2
    exit 1
fi

if [[ -e /dev/ttyUSB0 ]]; then
    DOCKER_DEVICES+=(--device /dev/ttyUSB0)
fi

docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker start -ai "$CONTAINER_NAME"
    exit 0
fi

docker run -it \
    --name "$CONTAINER_NAME" \
    "${DOCKER_DEVICES[@]}" \
    --group-add video \
    --security-opt seccomp=unconfined \
    -e HOME=/root \
    -e XDG_RUNTIME_DIR=/tmp \
    -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    -e PYGLFW_LIBRARY_VARIANT=wayland \
    -e GLFW_PLATFORM=wayland \
    -e QT_QPA_PLATFORM=wayland \
    -e SDL_VIDEODRIVER=wayland \
    -e GDK_BACKEND=wayland \
    -v "$HOST_WAYLAND_SOCKET:/tmp/$WAYLAND_DISPLAY" \
    -v "$WORKSPACE":/root \
    -w /root \
    --shm-size=8g \
    --network host \
    "$IMAGE_NAME" \
    bash -c '
        set -e
        mkdir -p /root/.local/bin
        if [ ! -x /root/.local/bin/uv ]; then
            curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR=/root/.local/bin sh
        fi
        printf "%s\n" "export PATH=\"/root/.local/bin:\$PATH\"" > /root/.local/bin/env
        for rc in /root/.zshrc /root/.zprofile /root/.profile /root/.bashrc; do
            [ -f "$rc" ] || continue
            sed -i \
                -e "s#export HOME=/main_workspace#export HOME=/root#g" \
                -e "s#export ZDOTDIR=/main_workspace#export ZDOTDIR=/root#g" \
                "$rc"
        done
        touch /root/.zshrc
        grep -qxF "export PATH=\"/root/.local/bin:\$PATH\"" /root/.zshrc || \
            printf "\nexport PATH=\"/root/.local/bin:\$PATH\"\n" >> /root/.zshrc
        grep -qxF "[ -f /root/.local/bin/env ] && . /root/.local/bin/env" /root/.zshrc || \
            printf "[ -f /root/.local/bin/env ] && . /root/.local/bin/env\n" >> /root/.zshrc
        touch /root/.vimrc
        grep -qxF "set encoding=utf-8" /root/.vimrc || cat >> /root/.vimrc <<'"'"'VIMRC'"'"'

set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,latin1
set termencoding=utf-8
VIMRC
        exec bash
    '
