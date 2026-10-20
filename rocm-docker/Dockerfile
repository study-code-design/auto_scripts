#FROM rocm/dev-ubuntu-20.04:6.3.4-complete
FROM rocm/dev-ubuntu-22.04:6.4.4-complete 

ENV UserName=rocmUser
ENV GroupName=rocmUser
ENV UID=1000
ENV GID=1000


RUN groupadd -g ${GID} ${GroupName} && \
    useradd -u ${UID} -g ${GroupName} -m -s /usr/bin/zsh ${UserName} && \
    echo "${UserName} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers


ENV TZ=Asia/Shanghai
ENV Home=/home/${UserName}
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV PATH=${Home}/.local/bin:${PATH}

ARG DEBIAN_FRONTEND=noninteractive



WORKDIR ${Home}


ARG UBUNTU_MIRROR=http://mirrors.aliyun.com/ubuntu
# ARG USERNAME=tu
# ARG UID=1000
# ARG GID=1000


RUN printf '%s\n' \
        "deb ${UBUNTU_MIRROR}/ jammy main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-updates main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-backports main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ jammy-security main restricted universe multiverse" \
    > /etc/apt/sources.list

# RUN groupadd -g "${GID}" "${USERNAME}" \
#     && useradd -m -u "${UID}" -g "${GID}" -s /usr/bin/bash "${USERNAME}" \
#     && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers



RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg2 \
        iproute2 \
        libdrm-amdgpu1 \
        libdrm-common \
        libdrm2 \
        libegl1-mesa \
        libgbm1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        locales \
        mesa-utils \
        mesa-vulkan-drivers \
        openssh-server \
        sudo \
        tree \
        tzdata \
        unzip \
        vim-gtk3 \
        wget \
        zsh \
        python3-venv \
        fzf \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# 安装oh-my-zsh（以rocmUser身份安装，安装脚本依赖HOME和用户环境）
COPY zsh_conf/zsh-install.sh /tmp/zsh-install.sh
RUN chmod +x /tmp/zsh-install.sh && \
    chown -R ${UserName}:${GroupName} ${Home} && \
    su - ${UserName} -c /tmp/zsh-install.sh && \
    rm /tmp/zsh-install.sh

COPY zsh_conf/.zshrc2 ${Home}/.zshrc
COPY zsh_conf/.p10k.zsh ${Home}/.p10k.zsh
RUN chown ${UserName}:${GroupName} ${Home}/.zshrc ${Home}/.p10k.zsh

# 安装yazi
RUN curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' | tee /etc/apt/sources.list.d/yazi.list >/dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends yazi && \
    rm -rf /var/lib/apt/lists/*


RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN curl -fsSL https://opencode.ai/install | bash
RUN curl https://getmic.ro | bash

USER rocmUser


CMD ["bash"]
