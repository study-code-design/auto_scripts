#!/usr/bin/env bash
export http_proxy=http://127.0.0.1:7890 https_proxy=http://127.0.0.1:7890 HTTP_PROXY=http://127.0.0.1:7890 HTTPS_PROXY=http://127.0.0.1:7890


docker build --network=host \
  --build-arg USERNAME=ros \
  --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) \
  --build-arg HTTP_PROXY=$http_proxy --build-arg HTTPS_PROXY=$https_proxy \
  --build-arg NO_PROXY=localhost,127.0.0.1,registry.npmmirror.com,npmmirror.com \
  -f quick_ubuntu/docker/Dockerfile -t ubuntu-ros .