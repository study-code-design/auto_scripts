# Ubuntu 22.04 基础镜像 + ZSH + oh-my-zsh + 插件 + powerlevel10k + node/npm + opencode
# 以非 root 用户运行,UID/GID 与宿主机对齐,便于 bind mount 双向读写同一份文件
#
# 构建(以仓库根目录为上下文,可传 USERNAME/UID/GID):
#   docker build --build-arg USERNAME=dev --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) \
#     -f quick_ubuntu/docker/Dockerfile -t ubuntu-zsh .
#
# 运行(默认进入用户家目录;共享目录建议挂到家目录下的子目录,如 -v $(pwd):/home/dev/work):
#   docker run -it -v $(pwd):/home/dev/work ubuntu-zsh

FROM ubuntu:22.04
# FROM ubuntu-zsh:latest

# ---- 可配置的用户信息:默认 dev,UID/GID 与宿主机一致 ----
ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000
# 是否用鱼香ROS一键安装 ROS2 humble 桌面版 + rosdepc(默认装,传 0 跳过)
ARG INSTALL_ROS=1

ENV TZ=Asia/Shanghai
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

# ---- 使用阿里云 Ubuntu 镜像源加速 apt ----
ARG UBUNTU_MIRROR=http://mirrors.aliyun.com/ubuntu

RUN printf '%s\n' \
        "deb ${UBUNTU_MIRROR}/ jammy main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-updates main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-backports main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-security main restricted universe multiverse" \
    > /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        libnotify-bin \
        locales \
        python3 \
        python3-pip \
        sudo \
        tree \
        unzip \
        wget \
        zsh \
        zenity \
	python3-env \ 
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# ---- 创建非 root 用户,默认 shell 直接设为 zsh,并赋予免密 sudo ----
RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s "$(which zsh)" ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME}

# ---- 切换到非 root 用户,HOME 即 /home/${USERNAME} ----
USER ${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}
WORKDIR ${HOME}

# ---- 安装 oh-my-zsh + 插件 + powerlevel10k ----
# GitHub 加速: 多个镜像，失败自动切换，全失败则直连 GitHub
RUN <<'EOF'
#!/usr/bin/env bash
set -e

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

    echo ">>> 安装 oh-my-zsh (非交互)..."
    RUNZSH=no bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

    ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

    echo ">>> 安装 zsh 插件..."
    run_with_mirror git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    run_with_mirror git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"

    echo ">>> 安装 powerlevel10k 主题..."
    run_with_mirror git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"

    echo ">>> 清理 git 全局加速配置..."
    for mirror in "https://ghfast.top/https://github.com/" "https://gh-proxy.com/https://github.com/"; do
        git config --global --unset-all "url.${mirror}.insteadOf" 2>/dev/null || true
    done
EOF

# ---- 安装 nvm / node / npm(装在用户家目录,软链到 ~/.local/bin 供全局使用) ----
# node 二进制走 npmmirror 镜像,避免直连 nodejs.org 过慢
RUN <<'EOF'
#!/usr/bin/env bash
set -e

    export NVM_NODEJS_ORG_MIRROR=https://npmmirror.com/mirrors/node/
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.6/install.sh | bash
    \. "$HOME/.nvm/nvm.sh"
    nvm install 24
    nvm alias default 24
    NODE_BIN="$(dirname "$(which node)")"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$NODE_BIN/node" "$HOME/.local/bin/node"
    ln -sf "$NODE_BIN/npm" "$HOME/.local/bin/npm"
    ln -sf "$NODE_BIN/npx" "$HOME/.local/bin/npx"
    node -v
    npm -v
EOF

# ---- 使用 npm 全局安装 opencode(走 npmmirror 源) ----
RUN <<'EOF'
#!/usr/bin/env bash
set -e

    \. "$HOME/.nvm/nvm.sh"
    npm config set registry https://registry.npmmirror.com
    npm install -g opencode-ai
    ln -sf "$(npm prefix -g)/bin/opencode" "$HOME/.local/bin/opencode"
    opencode --version
EOF

# ---- 复制 zsh 与 powerlevel10k 配置文件,属主改为 ${USERNAME} 用户 ----
COPY --chown=${USERNAME}:${USERNAME} zsh_conf/.zshrc ${HOME}/.zshrc
COPY --chown=${USERNAME}:${USERNAME} zsh_conf/.p10k.zsh ${HOME}/.p10k.zsh

# ---- 用鱼香ROS一键安装 ROS2 humble 桌面版 + rosdepc(自动应答,免交互) ----
# 脚本通过 ./fish_install.yaml 预填菜单答案,INSTALL_ROS=0 可跳过
COPY --chown=${USERNAME}:${USERNAME} quick_ubuntu/docker/install_ros_fishros.sh ${HOME}/install_ros_fishros.sh
RUN if [ "${INSTALL_ROS}" = "1" ]; then \
        bash ${HOME}/install_ros_fishros.sh; \
    fi && rm -f ${HOME}/install_ros_fishros.sh

# ---- 工作目录:把 ros2 项目当成 home,进入容器直接落在项目目录 ----
# 项目由 compose 挂载到 ${HOME}/ros2,运行时会覆盖这个空目录
RUN mkdir -p ${HOME}/ros2 && chown ${USERNAME}:${USERNAME} ${HOME}/ros2
WORKDIR ${HOME}/ros2

CMD ["zsh"]
