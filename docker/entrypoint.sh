#!/bin/bash
# entrypoint.sh - 容器启动时执行
set +e

mkdir -p "$HOME/.local/bin"

# 安装 uv
if [ ! -x "$HOME/.local/bin/uv" ]; then
  curl -LsSf https://astral.sh/uv/install.sh | env UV_INSTALL_DIR="$HOME/.local/bin" sh
fi

export PATH="$HOME/.local/bin:$PATH"

# 配置 shell
for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
  touch "$rc"
  grep -qxF "export PATH=\"$HOME/.local/bin:\$PATH\"" "$rc" || \
    printf '\nexport PATH="%s/.local/bin:$PATH"\n' "$HOME" >> "$rc"
  grep -qxF "export UV_PROJECT_ENVIRONMENT=\"$UV_PROJECT_ENVIRONMENT\"" "$rc" || \
    printf 'export UV_PROJECT_ENVIRONMENT="%s"\n' "$UV_PROJECT_ENVIRONMENT" >> "$rc"
done

# 配置 vim
if [ ! -L "$HOME/.vimrc" ]; then
  touch "$HOME/.vimrc"
  grep -qxF "set encoding=utf-8" "$HOME/.vimrc" || cat >> "$HOME/.vimrc" <<'VIMRC'
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8,ucs-bom,gb18030,gbk,gb2312,latin1
set termencoding=utf-8
VIMRC
fi

# 打印信息
printf "uid=%s gid=%s DISPLAY=%s WAYLAND_DISPLAY=%s HOME=%s\n" \
  "$(id -u)" "$(id -g)" "${DISPLAY:-<empty>}" "${WAYLAND_DISPLAY:-<empty>}" "$HOME"

exec bash
