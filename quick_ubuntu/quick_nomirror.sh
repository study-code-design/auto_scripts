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
# 3. 安装缺失工具 (zsh / brew / curl / git / uv / npm)
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

# zsh
if command -v zsh >/dev/null 2>&1; then
    echo ">>> 已存在 zsh，跳过。"
else
    echo ">>> 未检测到 zsh，调用 zsh 配置脚本..."
    ../zsh_conf/auto_install_nomirror.sh
fi

# brew
if command -v brew >/dev/null 2>&1; then
    echo ">>> 已存在 brew，跳过。"
else
    echo ">>> 未检测到 brew，开始安装 Homebrew..."
    /usr/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
