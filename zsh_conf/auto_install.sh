#!/usr/bin/bash
sudo apt update
sudo apt install -y zsh

# GitHub 加速:多个镜像，失败自动切换，全失败则直连 GitHub
run_with_mirror() {
    local -a gh_mirrors=(
        "https://ghfast.top/https://github.com/"
        "https://gh-proxy.com/https://github.com/"
    )
    local mirror
    for mirror in "${gh_mirrors[@]}"; do
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

RUNZSH=no bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
read -p "是否想安装zsh插件(y/n)?  (推荐)" choice
cd ~/.oh-my-zsh/custom/plugins/
if [[ $choice == "y" || $choice == "Y" ]]; then
    run_with_mirror git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    run_with_mirror git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 
else 
    echo "跳过插件安装"
fi
read -p "是否想安装powerlevel10k(y/n)?  (推荐)" install_p10k
if [[ $install_p10k != "y" && $install_p10k != "Y" ]]; then
    echo "跳过powerlevel10k安装"
    echo "运行chsh -s $(which zsh)将zsh设置为默认shell"
    exit 0
fi
cd ~/.oh-my-zsh/custom/themes/
run_with_mirror git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k



echo "安装完成! 请将zsh设置为默认shell并重启终端"
echo "如果你想设置默认终端，就接着输入密码运行下一步，否则ctrl+c退出"
chsh -s $(which zsh)
echo "你可以复制根目录的.zshrc文件到你~目录下作为配置文件"

# 自动复制配置文件到用户根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo ">>> 自动复制配置到 ~/"
if [ -f "$SCRIPT_DIR/.zshrc" ]; then
    cp "$SCRIPT_DIR/.zshrc" ~/.zshrc && echo "已复制 ~/.zshrc"
fi
if [ -f "$SCRIPT_DIR/.p10k.zsh" ]; then
    cp "$SCRIPT_DIR/.p10k.zsh" ~/.p10k.zsh && echo "已复制 ~/.p10k.zsh"
fi
