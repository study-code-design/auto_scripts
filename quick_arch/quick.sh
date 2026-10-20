#!/usr/bin/bash

set -euo pipefail

# ============================================================
# 0. 权限辅助
# ============================================================
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# ============================================================
# 1. 检测发行版
# ============================================================
if [ ! -r /etc/os-release ]; then
    echo "错误: 找不到 /etc/os-release，仅支持 Arch Linux。" >&2
    exit 1
fi

if ! grep -qE '^(ID|ID_LIKE)=.*(arch|Arch)' /etc/os-release; then
    echo "错误: 当前系统不是 Arch Linux。" >&2
    exit 1
fi

echo ">>> 检测到 Arch Linux"

# ============================================================
# 2. 配置中科大国内源
# ============================================================
configure_mirror() {
    local mirrorlist="/etc/pacman.d/mirrorlist"
    local backup="/etc/pacman.d/mirrorlist.bak.$(date +%Y%m%d%H%M%S)"
    local ustc_mirror="Server = https://mirrors.ustc.edu.cn/archlinux/\$repo/os/\$arch"

    if [ -f "$mirrorlist" ] && grep -q 'mirrors.ustc.edu.cn' "$mirrorlist"; then
        echo ">>> 已配置中科大源，跳过。"
        return 0
    fi

    [ -f "$mirrorlist" ] && $SUDO cp -a "$mirrorlist" "$backup"
    echo ">>> 原源配置已备份到: $backup"

    $SUDO sed -i "1i\\$ustc_mirror" "$mirrorlist"

    echo ">>> 已切换到中科大源，刷新软件列表..."
    $SUDO pacman -Syy --noconfirm
}

read -p ">>> 是否配置中科大源？[y/N] " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
    configure_mirror
fi

# ============================================================
# 2.5 安装 yay (AUR helper)
# ============================================================
install_yay() {
    if command -v yay >/dev/null 2>&1; then
        echo ">>> 已存在 yay，跳过。"
        return 0
    fi

    echo ">>> 未检测到 yay，开始安装..."
    $SUDO pacman -S --noconfirm --needed base-devel git

    local tmpdir
    tmpdir=$(mktemp -d)
    cd "$tmpdir"

    if ! command -v yay >/dev/null 2>&1; then
        git clone https://aur.archlinux.org/yay-bin.git
        cd yay-bin
        makepkg -si --noconfirm
    fi

    cd - >/dev/null
    rm -rf "$tmpdir"

    echo ">>> yay 安装完成。"
}
install_yay

# ============================================================
# 3. 安装缺失工具 (zsh / brew / curl / git / uv)
#    已存在的命令自动跳过
# ============================================================
need_pkgs=()
for c in curl git; do
    if command -v "$c" >/dev/null 2>&1; then
        echo ">>> 已存在 $c，跳过。"
    else
        need_pkgs+=("$c")
    fi
done

if [ "${#need_pkgs[@]}" -gt 0 ]; then
    echo ">>> 安装 yay 包: ${need_pkgs[*]}"
    yay -S --noconfirm --needed "${need_pkgs[@]}"
fi

# ============================================================
# 3.5 GitHub 加速:多个镜像，失败自动切换，命令结束自动还原
# ============================================================
GH_MIRRORS=(
    "https://ghfast.top/https://github.com/"
    "https://gh-proxy.com/https://github.com/"
)

run_with_mirror() {
    local mirror
    for mirror in "${GH_MIRRORS[@]}"; do
        git config --global "url.${mirror}.insteadOf" "https://github.com/"
        if "$@"; then
            return 0
        fi
        echo ">>> 加速镜像 ${mirror} 失败，尝试下一镜像..."
        git config --global --unset-all "url.${mirror}.insteadOf" 2>/dev/null || true
    done
    echo ">>> 所有加速镜像均不可用，回退为直连 GitHub..."
    "$@"
}

cleanup_gh_mirror() {
    for mirror in "${GH_MIRRORS[@]}"; do
        git config --global --unset-all "url.${mirror}.insteadOf" 2>/dev/null || true
    done
    echo ">>> 已取消 git 全局加速配置。"
}
trap cleanup_gh_mirror EXIT

# zsh
if command -v zsh >/dev/null 2>&1; then
    echo ">>> 已存在 zsh，跳过。"
else
    echo ">>> 未检测到 zsh，调用 zsh 配置脚本..."
    run_with_mirror ./auto_install.sh
fi

# brew
if command -v brew >/dev/null 2>&1; then
    echo ">>> 已存在 brew，跳过。"
else
    echo ">>> 未检测到 brew，开始安装 Homebrew..."
    run_with_mirror /usr/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# uv
if command -v uv >/dev/null 2>&1; then
    echo ">>> 已存在 uv，跳过。"
else
    echo ">>> 未检测到 uv，开始安装 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

if command -v npm >/dev/null 2>&1; then
    echo ">>> 已存在 npm，跳过。"
else
    echo ">>> 未检测到 npm，开始安装 npm"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
    \. "$HOME/.nvm/nvm.sh"
    nvm install 24
    node -v
    npm -v
fi

echo ">>> 全部完成。"
