ARG CUDA_VERSION=13.0.2
ARG USER_NAME=genesis
ARG GROUP_NAME=genesis
ARG USER_ID
ARG GROUP_ID


############################################################
# Stage For Runtime Image
############################################################
FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu24.04 AS base

# ---- Install dependencies with apt -----------------------
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        # development tools
        tmux git curl wget bash-completion \
    && keyring_path="/usr/share/keyrings/ros-archive-keyring.gpg" \
    && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o $keyring_path \
    && arch="$(dpkg --print-architecture)" \
    && code="$(. /etc/os-release && echo $UBUNTU_CODENAME)" \
    && echo "deb [arch=$arch signed-by=$keyring_path] http://packages.ros.org/ros2/ubuntu $code main" > /etc/apt/sources.list.d/ros2.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        # for ROS install
        software-properties-common \
        ros-jazzy-desktop ros-dev-tools \
        # for dependency(copy from official dockerfile)
        libgl1 libglu1-mesa libegl-dev libegl1 \
        libxrender1 libglib2.0-0 ffmpeg libgtk2.0-dev \
        pkg-config libvulkan-dev libgles2 libglvnd0 libglx0 \
        # for installing genesis
        python3-pip \
        # for docker utility
        gosu \
    ## rosdep initialize
    && rosdep init && rosdep update \
    ## clean up
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# ---- Install Pytorch -------------------------------------
ENV PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1
USER ubuntu
RUN pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu130 \
    && pip install nvidia-libnvcomp-cu13 nvidia-nvcomp-cu13
USER root


############################################################
# Stage For Builder Image
############################################################
FROM base AS builder

# ---- Install build tools ---------------------------------
RUN add-apt-repository ppa:ubuntu-toolchain-r/test \
    && apt update \
    && apt install -y --no-install-recommends \
        gcc-11 g++-11 patchelf \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# ---- prepare building ------------------------------------
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 110 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 110 \
    && curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && pip install "pybind11[global]" \
    # Install CMake (3.x.x version for luisa build)
    && wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc \
        | gpg --dearmor -o /usr/share/keyrings/kitware-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg]" \
        "https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/kitware.list \
    && printf "Package: cmake cmake-data cmake-doc\nPin: version 3.*\nPin-Priority: 1001\n" \
        > /etc/apt/preferences.d/cmake-3x \
    && apt update \
    && apt-get install -y cmake \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

# ---- Build LuisaRender -----------------------------------
USER ubuntu
COPY --chown=ubuntu:ubuntu libs/Genesis /tmp/Genesis
COPY --chown=ubuntu:ubuntu libs/build_luisa.sh /tmp/
RUN sh /tmp/build_luisa.sh $(python3 -V | cut -d" " -f2 | cut -d. -f1-2)


############################################################
# Stage For Runtime Image
############################################################
FROM base AS runtime

ARG USER_NAME
ARG GROUP_NAME
ARG USER_ID
ARG GROUP_ID

# ---- Install Genesis -------------------------------------
ENV PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

USER ubuntu
COPY --chown=ubuntu:ubuntu libs/Genesis /tmp/Genesis
RUN pip install PyOpenGL==3.1.5 \
    && pip install /tmp/Genesis \
    && pip install open3d numpy==1.26.4 \
    && rm -rf /tmp/Genesis

# ---- Install Genesis dependencies ------------------------
COPY --from=builder /Genesis/genesis/ext/ParticleMesher/ParticleMesherPy /home/genesis/.local/lib/python3.12/site-packages/genesis/ext/ParticleMesher/ParticleMesherPy
COPY --from=builder /Genesis/genesis/ext/LuisaRender/build/bin /home/genesis/.local/lib/python3.12/site-packages/genesis/ext/LuisaRender/build/bin

# ---- Setup ROS dependencies ------------------------------
USER root
COPY libs/genesis_ros /tmp/genesis_ros
RUN apt-get update \
    && . /opt/ros/jazzy/setup.sh \
    && rosdep install --from-paths /tmp/genesis_ros --ignore-src -r -y \
    && rm -rf /tmp/genesis_ros \
    && apt clean \
    && rm -rf /var/lib/apt/lists/*

COPY libs/Genesis/docker/10_nvidia.json /usr/share/glvnd/egl_vendor.d/10_nvidia.json
COPY libs/Genesis/docker/nvidia_icd.json /usr/share/vulkan/icd.d/nvidia_icd.json
COPY libs/Genesis/docker/nvidia_layers.json /etc/vulkan/implicit_layer.d/nvidia_layers.json

# ---- Create a non-root user ------------------------------
# Delete the configured ubuntu user and take over with
# the host OS's UID/GID.
RUN mv /home/ubuntu /home/${USER_NAME} \
    && userdel ubuntu || true \
    && groupdel ubuntu || true \
    && groupadd --gid ${GROUP_ID} ${GROUP_NAME} \
    && useradd --shell /bin/bash -u ${USER_ID} -g ${GROUP_ID} -m ${USER_NAME} \
    && chown -R ${USER_NAME}:${GROUP_NAME} /home/${USER_NAME}

# ---- Create workspace structure --------------------------
WORKDIR /workspace
RUN mkdir -p /workspace  \
    && cd /workspace \
    && mkdir build install src \
    && chown -R ${USER_NAME}:${GROUP_NAME} /workspace

# ---- set entrypoint script -------------------------------
RUN echo "#!/bin/bash\n\
set -e\n\
\n\
chown ${USER_NAME}:${GROUP_NAME} -R /workspace\n\
\n\
if [ \$# -eq 0 ]; then\n\
    exec gosu ${USER_NAME} /bin/bash\n\
else\n\
    exec gosu ${USER_NAME} \"\$@\"\n\
fi" > /entrypoint.sh \
    && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
