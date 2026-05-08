#!/usr/bin/env bash
set -euo pipefail

# ========== 🛠 唯一配置区 (改这里即可，无需动其他地方) ==========
IMAGE_NAME="rocm6.3.4ub20:root"
CONTAINER_NAME="rocm_dev"
WORKSPACE="/home/tu/Documents/cpp_project/rl_rocm"
CONTAINER_WORKSPACE="/workspace"
CONTAINER_HOME="${CONTAINER_WORKSPACE}"
UV_PROJECT_ENVIRONMENT=".venv"

# 🚩 解析启动模式
MODE="run"  # 默认前台交互
if [[ "${1:-}" == "--up" || "${1:-}" == "-u" ]]; then
    MODE="up"
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# 🔄 自动同步变量到 .env (解决 Compose 后台读取失效 + 免手动同步问题)
cat > "${SCRIPT_DIR}/.env" <<EOF
IMAGE_NAME=${IMAGE_NAME}
CONTAINER_NAME=${CONTAINER_NAME}
WORKSPACE=${WORKSPACE}
CONTAINER_WORKSPACE=${CONTAINER_WORKSPACE}
CONTAINER_HOME=${CONTAINER_HOME}
UV_PROJECT_ENVIRONMENT=${UV_PROJECT_ENVIRONMENT}
XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
DISPLAY=${DISPLAY:-}
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-0}
XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}
HSA_OVERRIDE_GFX_VERSION=11.0.0
EOF

# 🔨 镜像构建（按需）
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "🔨 Building image: $IMAGE_NAME"
  docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
fi

# 🧹 清理同名残留容器
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# 🚀 启动容器
cd "$SCRIPT_DIR"
if [[ "$MODE" == "up" ]]; then
    echo "🚀 服务模式启动 (后台运行)..."
    docker compose up -d dev-interactive
    echo "✅ 容器已在后台运行 (名称: $CONTAINER_NAME)。"
    echo "   进入终端: docker compose exec dev-interactive bash"
else
    echo "🚀 交互模式启动 (前台运行)..."
    docker compose run --rm --name "$CONTAINER_NAME" dev-interactive
fi