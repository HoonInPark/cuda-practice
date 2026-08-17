# ==============================================================================
# libSFM Development Container
#
# CUDA 12.9 · cuDNN 9.10 · TensorRT 10.12 · C++17 · Ubuntu 22.04
#
# Build:
#   docker build -f docker/dev-sfm.Dockerfile -t dev-sfm .
#
# Run (GPU + SSH on port 2222 + bind mount):
#   docker run --gpus all -d -p 2222:22 -v ${PWD}:/root/workspace/libSFM --name dev-sfm dev-sfm
#
# Connect:
#   ssh root@localhost -p 2222   (password: vmffkdlv777)
# ==============================================================================

FROM nvidia/cuda:12.9.1-devel-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive
ARG TZ=Asia/Seoul

# Pinned dependency versions
ARG CUDNN_VERSION=9.10.2.21-1
ARG TENSORRT_VERSION=10.12.0.36-1+cuda12.9
ARG SPDLOG_VERSION=1:1.9.2+ds-0.2
ARG ONETBB_VERSION=2021.5.0-7ubuntu2

# ==============================================================================
# Core system packages + dev tools
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        ninja-build \
        clang-14 \
        clangd-14 \
        clang-format-14 \
        clang-tidy-14 \
        lld-14 \
        lldb-14 \
        git \
        rsync \
        curl \
        wget \
        unzip \
        pkg-config \
        ca-certificates \
        software-properties-common \
        openssh-server \
        gdb \
        valgrind \
        strace \
        cmake \
        sudo \
        vim \
        locales \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Clang alternatives (version-suffix-free commands)
RUN update-alternatives --install /usr/bin/clang   clang   /usr/bin/clang-14   100 && \
    update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-14 100 && \
    update-alternatives --install /usr/bin/clangd  clangd  /usr/bin/clangd-14  100 && \
    update-alternatives --install /usr/bin/lld     lld     /usr/bin/lld-14     100

# ==============================================================================
# Python build tooling (extension module / wheel builds)
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        python3-setuptools \
        python3-wheel \
        python3-venv \
        python-is-python3 \
        pybind11-dev \
        patchelf \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_DISABLE_PIP_VERSION_CHECK=1

# ==============================================================================
# cuDNN 9.10
# ==============================================================================
RUN set -ex && \
    cd /tmp && \
    wget https://developer.download.nvidia.com/compute/cudnn/redist/cudnn/linux-x86_64/cudnn-linux-x86_64-9.10.2.21_cuda12-archive.tar.xz && \
    tar -xJvf cudnn-linux-x86_64-9.10.2.21_cuda12-archive.tar.xz && \
    cp -P cudnn-linux-x86_64-9.10.2.21_cuda12-archive/include/cudnn*.h /usr/local/cuda/include && \
    cp -P cudnn-linux-x86_64-9.10.2.21_cuda12-archive/lib/libcudnn* /usr/local/cuda/lib64 && \
    chmod a+r /usr/local/cuda/include/cudnn*.h /usr/local/cuda/lib64/libcudnn* && \
    rm -rf /tmp/cudnn-linux-x86_64-9.10.2.21_cuda12-archive*

# ==============================================================================
# TensorRT 10.12
# ==============================================================================
RUN set -ex && \
    cd /tmp && \
    wget https://developer.nvidia.com/downloads/compute/machine-learning/tensorrt/10.12.0/tars/TensorRT-10.12.0.36.Linux.x86_64-gnu.cuda-12.9.tar.gz && \
    tar -xvf TensorRT-10.12.0.36.Linux.x86_64-gnu.cuda-12.9.tar.gz && \
    rm TensorRT-10.12.0.36.Linux.x86_64-gnu.cuda-12.9.tar.gz && \
    mv TensorRT-10.12.0.36 /usr/local/tensorrt && \
    cd / && \
    rm -rf /tmp/*
    
# ==============================================================================
# Project library dependencies (system packages — CMake resolves these as-is)
# ==============================================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
        libspdlog-dev=${SPDLOG_VERSION} \
        libtbb-dev=${ONETBB_VERSION} \
        libopencv-dev \
    && rm -rf /var/lib/apt/lists/*

# ==============================================================================
# SSH server (remote host development)
# ==============================================================================
RUN mkdir -p /run/sshd && \
    mkdir -p /root/workspace/libSFM && \
    chmod 711 /root && \
    chmod 755 /root/workspace /root/workspace/libSFM && \
    echo "root:vmffkdlv777" | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/'            /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    echo "export PATH=/usr/local/cuda/bin:\$PATH"                          >> /etc/profile.d/cuda.sh && \
    echo "export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH"  >> /etc/profile.d/cuda.sh

# ==============================================================================
# Environment
# ==============================================================================
ENV PATH="/usr/local/bin:/usr/local/cuda/bin:${PATH}"
ENV LD_LIBRARY_PATH="/usr/local/cuda/lib64:${LD_LIBRARY_PATH}"
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

WORKDIR /root/workspace/libSFM

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]

