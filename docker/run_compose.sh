#!/usr/bin/env bash
set -euo pipefail

# # ========== 1. 解析启动模式 ==========
# MODE="run"  # 默认交互模式
# if [[ "${1:-}" == "--up" || "${1:-}" == "-u" ]]; then
#     MODE="up"
#     shift  # 移除 --up 参数，后面的位置参数照常解析
# fi

# ========== 2. 参数与变量解析 ==========
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${1:-${IMAGE_NAME:-rocm6.3.4ub20:root}}"
CONTAINER_NAME="${2:-${CONTAINER_NAME:-rocm_dev}}"
WORKSPACE="${WORKSPACE:-/home/tu/Documents/cpp_project/rl_rocm}"
CONTAINER_WORKSPACE="${CONTAINER_WORKSPACE:-/workspace}"
CONTAINER_HOME="${CONTAINER_HOME:-${CONTAINER_WORKSPACE}}"
UV_PROJECT_ENVIRONMENT="${UV_PROJECT_ENVIRONMENT:-.venv}"

# ========== 3. 导出环境变量 ==========
export \
  IMAGE_NAME \
  CONTAINER_NAME \
  WORKSPACE \
  CONTAINER_WORKSPACE \
  CONTAINER_HOME \
  UV_PROJECT_ENVIRONMENT \
  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
  DISPLAY="${DISPLAY:-}" \
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-0}" \
  XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ========== 4. 镜像构建（按需） ==========
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "🔨 Building image: $IMAGE_NAME"
  docker build -t "$IMAGE_NAME" -f "$SCRIPT_DIR/Dockerfile" "$SCRIPT_DIR"
fi

# ========== 5. 清理同名容器 ==========
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
fi

# ========== 6. 根据模式启动 ==========
# cd "$SCRIPT_DIR"
# if [[ "$MODE" == "up" ]]; then
#     echo "🚀 服务模式启动 (后台运行)..."
#     # up 模式不传 --name，直接使用 docker-compose.yml 中 container_name 定义的名字
#     docker compose up -d dev-interactive
#     echo "✅ 容器已在后台运行。"
#     echo "   进入交互终端: docker compose exec dev-interactive bash"
#     echo "   查看实时日志: docker compose logs -f dev-interactive"
# else
#     echo "🚀 交互模式启动 (前台运行)..."
#     docker compose run --rm --name "$CONTAINER_NAME" dev-interactive
# fi

echo "🚀 交互模式启动 (前台运行)..."
docker compose run --rm --name "$CONTAINER_NAME" dev-interactive