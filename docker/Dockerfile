FROM rocm/dev-ubuntu-20.04:6.3.4-complete

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
        build-essential \
        ca-certificates \
        cmake \
        curl \
        git \
        locales \
        sudo \
        tzdata \
        vim-gtk3 \
        wget \
        zsh \
        tree \
    && locale-gen en_US.UTF-8 zh_CN.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sSfL https://hf.co/git-xet/install.sh | sh \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    curl -LsSf https://hf.co/cli/install.sh | bash

RUN chsh -s /usr/bin/zsh    


CMD ["bash"]
