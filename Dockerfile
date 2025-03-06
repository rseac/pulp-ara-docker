FROM ubuntu:22.04 as base

ENV DEBIAN_FRONTEND=noninteractive
RUN apt -y update && apt -y upgrade && apt -y install \
    build-essential \
    git \
    zlib1g \
    zlib1g-dev \
    pkg-config \
    cmake \
    vim

FROM base as ara-clone
RUN git clone https://github.com/pulp-platform/ara.git 

# Needs to be the evelop branch to get RVV instructions
FROM ara-clone as ara-update
RUN cd ara/cheshire/sw && git clone https://github.com/moimfeld/cva6-sdk.git && cd ../../ && git submodule update --init --recursive 

FROM ara-update as ara-make
RUN apt-get -y install ninja-build python3 texinfo
RUN cd ara && make toolchain-llvm 
WORKDIR /ara

FROM ara-make as ara-build
RUN apt-get -y install device-tree-compiler
RUN make riscv-isa-sim

FROM ara-build as ara-verilator
RUN apt-get --no-install-recommends -y install autoconf automake bc bison clang flex \
    ca-certificates \
    ccache \
    libfl2 \ 
    libfl-dev \
    help2man

FROM ara-verilator as ara-2
RUN make verilator

FROM ara-2 as ara-hardware
RUN apt-get --no-install-recommends -y install curl libelf-dev && cd /ara/install/verilator/share/verilator/ && ln -s /ara/install/verilator/bin/verilator_bin . 
RUN cd hardware && make checkout && make apply-patches && make verilate

FROM ara-hardware as ara-hello
RUN apt-get install -y pip && pip install -U numpy
RUN cd /ara/apps && make bin/hello_world && cd /ara/hardware && app=hello_world make simv
