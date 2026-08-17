FROM ubuntu:22.04

ARG WORKSPACE=/root/workspace

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \

        pkg-config \
	
	openssh-server \
	rsync \
	
	wget \
	curl \
	gnupg-agent \
	ca-certificates \	

        tar \

        cmake \
        build-essential \
        clang \
        gcc \
        g++ \
        gdb \

        && rm -rf /var/lib/apt/lists/*

# for ssh development
RUN mkdir /var/run/sshd && \
	sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
	sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# make symbolic link to default python3 installed in ubuntu 22.04
RUN ln -sf /usr/bin/python3 /usr/bin/python

RUN useradd dev -u 1000 -m -s /bin/bash

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
