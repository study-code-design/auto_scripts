# Ubuntu 22.04 + ROS2 humble + 鱼香ROS,以非 root 用户运行(UID/GID 与宿主机对齐)。
# 注意:oh-my-zsh/nvm/node/opencode 等 home 级工具已不在镜像内,
# 整个 home 由 compose 从宿主机挂载(~/Documents/project/ros2),工具随 home 持久化。
#
# 构建(以仓库根目录为上下文,可传 USERNAME/UID/GID):
#   docker build --build-arg USERNAME=ros --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) \
#     -f quick_ubuntu/docker/Dockerfile -t ub22-ros:humble .
#
# 运行:
#   docker compose -f quick_ubuntu/docker/docker-compose.yaml up -d

FROM ubuntu:22.04

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
        python3-venv \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 下载UV
RUN curl -LsSf https://astral.sh/uv/install.sh | sh


# ---- 创建非 root 用户,默认 shell 直接设为 zsh,并赋予免密 sudo ----
RUN groupadd -g ${USER_GID} ${USERNAME} \
    && useradd -m -u ${USER_UID} -g ${USER_GID} -s "$(which zsh)" ${USERNAME} \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/${USERNAME}

# ---- 切换到非 root 用户,HOME 即 /home/${USERNAME} ----
USER ${USERNAME}
ENV HOME=/home/${USERNAME}
ENV PATH=${HOME}/.local/bin:${PATH}
WORKDIR ${HOME}

# ---- home 级工具(oh-my-zsh/nvm/node/opencode)已移出镜像 ----
# 整个 home 由 compose 从宿主机挂载(~/Documents/project/ros2),这些工具随 home 一并持久化,
# 首次数据从备份镜像 ub22-ros:humble-backup-20260813 复制而来。

# ---- 用鱼香ROS一键安装 ROS2 humble 桌面版 + rosdepc(自动应答,免交互) ----
# 脚本通过 ./fish_install.yaml 预填菜单答案,INSTALL_ROS=0 可跳过
# 注意:暂注释以复用已有镜像的 ROS,构建完成后取消注释
COPY --chown=${USERNAME}:${USERNAME} quick_ubuntu/docker/install_ros_fishros.sh ${HOME}/install_ros_fishros.sh
RUN if [ "${INSTALL_ROS}" = "1" ]; then \
        bash ${HOME}/install_ros_fishros.sh; \
     fi && rm -f ${HOME}/install_ros_fishros.sh

# ---- 工作目录:进入容器默认落在用户家目录 ----
WORKDIR ${HOME}

CMD ["zsh"]
