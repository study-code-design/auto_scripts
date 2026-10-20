#!/usr/bin/env bash
# 使用鱼香ROS一键安装脚本,通过 FISH_INSTALL_CONFIG 配置文件自动应答,全程免交互
# 用法: 容器内直接运行本脚本,或在 Dockerfile 中 RUN 本脚本
#
# 答案说明(按出现顺序):
#   第1次运行 -> 菜单1: 一键安装ROS
#     1. 主菜单       -> 1 安装ROS
#     2. 换源提示     -> 2 不更换继续安装(镜像已配阿里源)
#     3. ROS版本      -> 1 humble(字母序排最前)
#     4. 桌面版/基础版 -> 1 桌面版
#   第2次运行 -> 菜单3: 安装rosdepc
#     1. 主菜单       -> 3 rosdepc
#     2. pip源        -> 2 阿里云

set -euo pipefail

cd "$HOME"

# ---------- 第1步:安装 ROS2 humble 桌面版 ----------
echo ">>> [1/2] 安装 ROS2 humble 桌面版 (自动应答)..."
cat > ./fish_install.yaml <<'YAML'
chooses:
  - {choose: 1, desc: ""}   # 主菜单:一键安装ROS
  - {choose: 2, desc: ""}   # 换源提示:不更换
  - {choose: 1, desc: ""}   # ROS镜像源:中科大
  - {choose: 1, desc: ""}   # 版本:humble
  - {choose: 1, desc: ""}   # 桌面版
YAML

wget http://fishros.com/install -O fishros
# 用 bash 子进程运行,避免 set -e 被脚本内部 source 的 profile 干扰
bash fishros
rm -f ./fishros ./fish_install.yaml

# ---------- 第2步:安装 rosdepc ----------
echo ">>> [2/2] 安装 rosdepc (自动应答)..."
cat > ./fish_install.yaml <<'YAML'
chooses:
  - {choose: 3, desc: ""}   # 主菜单:rosdepc
  - {choose: 3, desc: ""}   # pip源:中科大
YAML

wget http://fishros.com/install -O fishros
bash fishros
rm -f ./fishros ./fish_install.yaml

# ---------- 让 ros2 命令在 zsh 中直接可用 ----------
if [ -d /opt/ros/humble ]; then
    grep -q "source /opt/ros/humble/setup.zsh" "$HOME/.zshrc" 2>/dev/null || \
        echo "source /opt/ros/humble/setup.zsh" >> "$HOME/.zshrc"
fi

echo ">>> 全部完成。验证: ros2 --version"
