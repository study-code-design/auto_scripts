#!/bin/bash
sudo apt update
sudo apt install zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
read -p "是否想安装zsh插件(y/n)?  (推荐)" choice
cd ~/.oh-my-zsh/custom/plugins/
if [[ $choice == "y" || $choice == "Y" ]]; then
    git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
    git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting 
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
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k



echo "安装完成! 请将zsh设置为默认shell并重启终端"
echo "如果你想设置默认终端，就接着输入密码运行下一步，否则ctrl+c退出"
chsh -s $(which zsh)
echo "你可以复制根目录的.zshrc文件到你~目录下作为配置文件"
