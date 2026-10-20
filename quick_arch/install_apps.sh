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
    ["vofa+"]="vofa-bin"
    ["python3-dev"]="python"
    ["python3-venv"]="python"
    ["python3-pip"]="python-pip"
    ["bluetoothctl"]="bluez"
    ["snipaste"]="snipaste-bin"
    ["Moonlight"]="moonlight-qt"
    ["ProtonPlus"]="protonplus"
    ["Resources"]="resources"
    ["pycharm"]="pycharm-professional"
    ["clion"]="clion"
)

installed=()
skipped=()
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
echo ">>> 已安装: ${installed[*]:-无}"
echo ">>> 已跳过: ${skipped[*]:-无}"
echo ">>> 失败:   ${failed[*]:-无}"
echo ">>> =================================="
