#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 安装 oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  RUNZSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# 3. 克隆第三方插件
ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"
clone_plugin() {
  local repo=$1 name=$2
  [ -d "$ZSH_CUSTOM/plugins/$name" ] || git clone --depth=1 "https://github.com/$repo" "$ZSH_CUSTOM/plugins/$name"
}
clone_plugin zsh-users/zsh-autosuggestions zsh-autosuggestions
clone_plugin zsh-users/zsh-syntax-highlighting zsh-syntax-highlighting
clone_plugin zsh-users/zsh-completions zsh-completions
clone_plugin agkozak/zsh-z zsh-z

# 4. 安装 powerlevel10k 主题
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
  git clone --depth=1 "https://github.com/romkatv/powerlevel10k.git" "$P10K_DIR"
fi

# 5. 配置 ~/.zshrc（p10k 主题 + 插件 + instant prompt）
python3 - "$HOME/.zshrc" <<'EOF'
import re, sys
path = sys.argv[1]
with open(path) as f:
    content = f.read()

instant_prompt = """if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

"""
if "p10k-instant-prompt" not in content:
    content = instant_prompt + content

content = re.sub(r'^ZSH_THEME=.*', 'ZSH_THEME="powerlevel10k/powerlevel10k"', content, count=1, flags=re.MULTILINE)

plugins = """plugins=(
  git
  z
  extract
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  colored-man-pages
  command-not-found
)"""
content = re.sub(r"plugins=\([^)]*\)", plugins, content, count=1)

p10k_source = "\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n"
if "source ~/.p10k.zsh" not in content:
    content = content.rstrip() + "\n" + p10k_source

with open(path, "w") as f:
    f.write(content)
EOF

# 6. 复制 p10k 配置文件（如果同目录下有 .p10k.zsh）
if [ -f "$SCRIPT_DIR/.p10k.zsh" ]; then
  cp "$SCRIPT_DIR/.p10k.zsh" ~/.p10k.zsh
  echo "已复制 .p10k.zsh 配置"
fi

# 7. 完成
echo "安装完成，重新打开终端或执行 exec zsh 生效"