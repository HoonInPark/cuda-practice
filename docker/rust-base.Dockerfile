FROM os-base

ENV DEBIAN_FRONTEND=noninteractive

# cuda, cudnn, tensorrt
RUN wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb && \
        dpkg -i cuda-keyring_1.1-1_all.deb && \
        apt-get update && apt-get -y install \
        cuda-toolkit-13-1

RUN apt-get update && apt-get -y install \
        cudnn9-cuda-13

RUN apt-get update && apt-get -y install \
        tensorrt-dev

# clean
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
