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
# 1. 检测发行版与版本代号
# ============================================================
if [ ! -r /etc/os-release ]; then
    echo "错误: 找不到 /etc/os-release，仅支持 Ubuntu。" >&2
    exit 1
fi

if ! grep -qE '^(ID|ID_LIKE)=.*ubuntu' /etc/os-release; then
    echo "错误: 当前系统不是 Ubuntu。" >&2
    exit 1
fi

if command -v lsb_release >/dev/null 2>&1; then
    CODENAME=$(lsb_release -cs)
else
    CODENAME=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2 || true)
fi
CODENAME=${CODENAME:-unknown}
echo ">>> 检测到 Ubuntu 版本代号: $CODENAME"

# ============================================================
# 2. 配置中科大国内源
# ============================================================
configure_mirror() {
    local list_file="/etc/apt/sources.list"
    local deb822_file="/etc/apt/sources.list.d/ubuntu.sources"
    local backup_dir="/etc/apt/sources.list.bak.$(date +%Y%m%d%H%M%S)"

    # 若已是中科大源则跳过
    if { [ -f "$list_file" ]   && grep -q 'mirrors.ustc.edu.cn' "$list_file"; } || \
       { [ -f "$deb822_file" ] && grep -q 'mirrors.ustc.edu.cn' "$deb822_file"; }; then
        echo ">>> 已配置中科大源，跳过。"
        return 0
    fi

    $SUDO mkdir -p "$backup_dir"
    [ -f "$list_file" ]   && $SUDO cp -a "$list_file"   "$backup_dir/"
    [ -f "$deb822_file" ] && $SUDO cp -a "$deb822_file" "$backup_dir/"
    echo ">>> 原源配置已备份到: $backup_dir"

    # 经典 list 格式 (<= 22.04)
    if [ -f "$list_file" ]; then
        $SUDO sed -i \
            -e 's|http://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|https://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|http://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|https://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            "$list_file"
    fi

    # deb822 格式 (24.04+)
    if [ -f "$deb822_file" ]; then
        $SUDO sed -i \
            -e 's|http://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|https://archive.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|http://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            -e 's|https://security.ubuntu.com/ubuntu|https://mirrors.ustc.edu.cn/ubuntu|g' \
            "$deb822_file"
    fi

    # 若两种格式都不存在，则按 deb822 重建一份
    if [ ! -f "$list_file" ] && [ ! -f "$deb822_file" ]; then
        echo ">>> 未找到现有源文件，写入中科大源 ($CODENAME)..."
        $SUDO tee "$deb822_file" >/dev/null <<EOF
Types: deb
URIs: https://mirrors.ustc.edu.cn/ubuntu/
Suites: ${CODENAME} ${CODENAME}-updates ${CODENAME}-backports
Components: main universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: https://mirrors.ustc.edu.cn/ubuntu/
Suites: ${CODENAME}-security
Components: main universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
EOF
    fi

    echo ">>> 已切换到中科大源，刷新软件列表..."
    $SUDO apt-get update
    $SUDO apt update
}
configure_mirror

# ============================================================
# 3. 安装缺失工具 (zsh / brew / curl / git / uv)
#    已存在的命令自动跳过
# ============================================================
need_apt=()
for c in curl git; do
    if command -v "$c" >/dev/null 2>&1; then
        echo ">>> 已存在 $c，跳过。"
    else
        need_apt+=("$c")
    fi
done

if [ "${#need_apt[@]}" -gt 0 ]; then
    echo ">>> 安装 apt 包: ${need_apt[*]}"
    $SUDO apt install -y "${need_apt[@]}"
fi

# ============================================================
# 3.5 GitHub 加速:多个镜像，失败自动切换，命令结束自动还原
# ============================================================
GH_MIRRORS=(
    "https://ghfast.top/https://github.com/"
    "https://gh-proxy.com/https://github.com/"
)

# 依次尝试每个镜像执行给定命令，直到成功；全失败则直连 GitHub
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
    run_with_mirror ../zsh_conf/auto_install.sh
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
    # Verify the Node.js version:
    node -v # Should print "v24.19.0".
    # Verify npm version:
    npm -v # Should print "11.17.0".
fi

echo ">>> 全部完成。"
