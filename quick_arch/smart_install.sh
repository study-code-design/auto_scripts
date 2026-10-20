#!/usr/bin/bash

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_FILE="$SCRIPT_DIR/../app.txt"

if [ ! -f "$APP_FILE" ]; then
    echo "错误: 找不到 app.txt 文件 ($APP_FILE)" >&2
    exit 1
fi

declare -A CHECK_MAP=(
    ["git"]="git"
    ["git-lfs"]="git-lfs"
    ["git-filter-repo"]="git-filter-repo"
    ["curl"]="curl"
    ["wget"]="wget"
    ["tree"]="tree"
    ["brew"]="brew"
    ["zsh"]="zsh"
    ["vim"]="vim"
    ["nvim"]="nvim"
    ["unzip"]="unzip"
    ["unrar"]="unrar"
    ["fastfetch"]="fastfetch"
    ["opencode"]="opencode"
    ["bzip2"]="bzip2"
    ["pnpm"]="pnpm"
    ["uv"]="uv"
    ["sddm"]="sddm"
    ["VSCode"]="code"
    ["Google Chrome"]="google-chrome"
    ["Firefox"]="firefox"
    ["WeChat"]="wechat"
    ["LinuxQQ"]="linuxqq"
    ["BaiduNetdisk"]="baidunetdisk"
    ["WPS Office"]="wps"
    ["Wemeet"]="wemeet"
    ["OBS Studio"]="obs"
    ["Lutris"]="lutris"
    ["Wine"]="wine"
    ["Moonlight"]="moonlight"
    ["Sunshine"]="sunshine"
    ["ProtonPlus"]="protonplus"
    ["Steam"]="steam"
    ["Xournal++"]="xournalpp"
    ["XMind"]="xmind"
    ["GitHub Desktop"]="github-desktop"
    ["Resources"]="resources"
    ["Electerm"]="electerm"
    ["localsend"]="localsend"
    ["escrcpy"]="escrcpy"
    ["handy"]="handy"
    ["vofa+"]="vofa"
    ["font-manager"]="font-manager"
    ["fcitx5"]="fcitx5"
    ["python3-dev"]="python3"
    ["python3-venv"]="python3"
    ["python3-pip"]="pip"
    ["net-tools"]="netstat"
    ["flatpak"]="flatpak"
    ["nodejs"]="node"
    ["bluetoothctl"]="bluetoothctl"
    ["cmake"]="cmake"
    ["pandoc"]="pandoc"
    ["rickrack"]="rickrack"
    ["obsidian"]="obsidian"
    ["clion"]="clion"
    ["pycharm"]="pycharm"
    ["snipaste"]="snipaste"
    ["rocm"]="rocm-smi"
)

declare -A PKG_MAP=(
    ["brew"]="请手动运行: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    ["uv"]="请手动运行: curl -LsSf https://astral.sh/uv/install.sh | sh"
    ["opencode"]="请手动运行: curl -fsSL https://opencode.ai/install | bash"
    ["VSCode"]="visual-studio-code-bin"
    ["Google Chrome"]="google-chrome"
    ["WeChat"]="wechat-universal"
    ["LinuxQQ"]="linuxqq"
    ["BaiduNetdisk"]="baidunetdisk-bin"
    ["WPS Office"]="wps-office"
    ["OBS Studio"]="obs-studio"
    ["Xournal++"]="xournalpp"
    ["GitHub Desktop"]="github-desktop-bin"
    ["Electerm"]="electerm-bin"
    ["python3-dev"]="python"
    ["python3-venv"]="python"
    ["python3-pip"]="python-pip"
    ["bluetoothctl"]="bluez"
    ["snipaste"]="snipaste-bin"
    ["Moonlight"]="moonlight-qt"
    ["ProtonPlus"]="protonplus"
    ["Resources"]="resources"
    ["pycharm"]="pycharm-professional"
)

installed=()
skipped=()
already_have=()
failed=()

while IFS= read -r -u 3 app || [ -n "$app" ]; do
    app="${app#"${app%%[![:space:]]*}"}"
    app="${app%"${app##*[![:space:]]}"}"
    [ -z "$app" ] && continue

    pkg="$app"
    if [[ -n "${PKG_MAP[$app]+x}" ]]; then
        pkg="${PKG_MAP[$app]}"
    fi

    if [[ "$pkg" == 请手动* ]]; then
        read -p ">>> [$app] 需要手动安装，是否查看安装命令？[y/N] " answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            echo "  $pkg"
        fi
        skipped+=("$app")
        continue
    fi

    check_cmd="${CHECK_MAP[$app]:-$app}"
    if command -v "$check_cmd" >/dev/null 2>&1; then
        echo ">>> [$app] 已安装 ($check_cmd)，跳过。"
        already_have+=("$app")
        continue
    fi

    if yay -Qq "$pkg" >/dev/null 2>&1; then
        echo ">>> [$app] 已安装 (包: $pkg)，跳过。"
        already_have+=("$app")
        continue
    fi

    read -p ">>> 是否安装 $app [$pkg]？[y/N] " answer
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        if yay -S --noconfirm --needed "$pkg"; then
            installed+=("$app")
        else
            echo ">>> $app 安装失败"
            failed+=("$app")
        fi
    else
        skipped+=("$app")
    fi
done 3< "$APP_FILE"

echo ""
echo ">>> ============ 安装总结 ============"
echo ">>> 已拥有: ${already_have[*]:-无}"
echo ">>> 已安装: ${installed[*]:-无}"
echo ">>> 已跳过: ${skipped[*]:-无}"
echo ">>> 失败:   ${failed[*]:-无}"
echo ">>> =================================="
