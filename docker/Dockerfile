# FROM rocm/dev-ubuntu-20.04:6.3.4-complete
FROM rocm6-3-4_ubuntu20:latest

ENV TZ=Asia/Shanghai
ENV HOME=/root
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
ENV DEBIAN_FRONTEND=noninteractive
ENV PATH=/root/.local/bin:${PATH}

WORKDIR /root

ARG UBUNTU_MIRROR=http://mirrors.aliyun.com/ubuntu

RUN printf '%s\n' \
        "deb ${UBUNTU_MIRROR}/ focal main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ focal-updates main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ focal-backports main restricted universe multiverse" \
        "deb ${UBUNTU_MIRROR}/ focal-security main restricted universe multiverse" \
    > /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        apt-transport-https \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        gnupg2 \
        locales \
        python3-launchpadlib \
        software-properties-common \
        sudo \
        tzdata \
        unzip \
        vim-gtk3 \
        wget \
        zsh \
        tree \
    && add-apt-repository -y ppa:kisak/turtle \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libdrm-amdgpu1 \
        libdrm-common \
        libdrm2 \
        libegl1-mesa \
        libgbm1 \
        libgl1-mesa-dri \
        libglx-mesa0 \
        mesa-utils \
        mesa-vulkan-drivers \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN set -eux; \
    echo "Skipping oh-my-zsh install during image build."; \
    echo "Skipping git-xet install on Ubuntu 20.04: current installer requires newer OpenSSL/libssl.so.3."; \
    if python3 -c 'import sys; raise SystemExit(0 if sys.version_info >= (3, 10) else 1)'; then \
        curl -LsSf https://hf.co/cli/install.sh | bash; \
    else \
        echo "Skipping Hugging Face CLI installer: Python 3.10+ is required, base image provides $(python3 --version 2>&1)."; \
    fi

RUN chsh -s /usr/bin/zsh    


CMD ["bash"]
