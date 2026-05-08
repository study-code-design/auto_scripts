#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${1:-${IMAGE_NAME:-rocm6.3.4ub20:root}}"
CONTAINER_NAME="${2:-${CONTAINER_NAME:-rocm6.3.4ub20_norm_test2}}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE="${WORKSPACE:-/home/tu/Documents/cpp_project/rl_rocm}"
CONTAINER_WORKSPACE="${CONTAINER_WORKSPACE:-/workspace}"
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
# CONTAINER_HOME="${CONTAINER_HOME:-${CONTAINER_WORKSPACE}/.container-home}"
CONTAINER_HOME="${CONTAINER_HOME:-${CONTAINER_WORKSPACE}}"

UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-.venv}"

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

if [[ -e /dev/ttyUSB0 ]]; then
    DOCKER_DEVICES+=(--device /dev/ttyUSB0)
fi

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
fi

if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

    # --user "${HOST_UID}:${HOST_GID}" \
docker run -it  --rm \
    --name "$CONTAINER_NAME" \
    "${DOCKER_DEVICES[@]}" \
    --group-add video \
    --group-add render \
    --security-opt seccomp=unconfined \
    -e HOME="${CONTAINER_HOME}" \
    -e PATH="${CONTAINER_HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    -e DISPLAY="${DISPLAY:-}" \
    -e WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
    -e VIRTUAL_ENV= \
    -e UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT}" \
    -v "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}:${XDG_RUNTIME_DIR:-/run/user/$(id -u)}:rw" \
    -v /tmp/.X11-unix:/tmp/.X11-unix:rw \
    -e XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}" \
    -v "${XAUTHORITY:-$HOME/.Xauthority}:${XAUTHORITY:-$HOME/.Xauthority}:ro" \
    -v "$WORKSPACE":"$CONTAINER_WORKSPACE" \
    -e XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}" \
    -v "${XDG_RUNTIME_DIR:-/run/user/1000}:${XDG_RUNTIME_DIR:-/run/user/1000}:rw" \
    -w "$CONTAINER_WORKSPACE" \
    -v /usr/lib/firmware/amdgpu:/lib/firmware/amdgpu:ro \
    --shm-size=8g \
    --network host \
    "$IMAGE_NAME" \
    bash -c '
        set +e

        mkdir -p "$HOME/.local/bin"
        if [ ! -x "$HOME/.local/bin/uv" ]; then
            curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh
        fi
        export PATH="$HOME/.local/bin:$PATH"
        touch "$HOME/.bashrc" "$HOME/.zshrc"
        grep -qxF "export PATH=\"$HOME/.local/bin:\$PATH\"" "$HOME/.bashrc" || \
            printf "\nexport PATH=\"%s/.local/bin:\$PATH\"\n" "$HOME" >> "$HOME/.bashrc"
        grep -qxF "export UV_PROJECT_ENVIRONMENT=\"$UV_PROJECT_ENVIRONMENT\"" "$HOME/.bashrc" || \
            printf "export UV_PROJECT_ENVIRONMENT=\"%s\"\n" "$UV_PROJECT_ENVIRONMENT" >> "$HOME/.bashrc"
        grep -qxF "export PATH=\"$HOME/.local/bin:\$PATH\"" "$HOME/.zshrc" || \
            printf "\nexport PATH=\"%s/.local/bin:\$PATH\"\n" "$HOME" >> "$HOME/.zshrc"
        grep -qxF "export UV_PROJECT_ENVIRONMENT=\"$UV_PROJECT_ENVIRONMENT\"" "$HOME/.zshrc" || \
            printf "export UV_PROJECT_ENVIRONMENT=\"%s\"\n" "$UV_PROJECT_ENVIRONMENT" >> "$HOME/.zshrc"
        if [ ! -L "$HOME/.vimrc" ]; then
            touch "$HOME/.vimrc"
            grep -qxF "set encoding=utf-8" "$HOME/.vimrc" || cat >> "$HOME/.vimrc" <<'"'"'VIMRC'"'"'

set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,latin1
set termencoding=utf-8
VIMRC
        fi
        printf "uid=%s gid=%s DISPLAY=%s WAYLAND_DISPLAY=%s HOME=%s\n" \
            "$(id -u)" "$(id -g)" "${DISPLAY:-<empty>}" "${WAYLAND_DISPLAY:-<empty>}" "$HOME"
        exec bash
    '
