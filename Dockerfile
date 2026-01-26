ARG CUDA_VERSION=13.0.2
ARG USER_NAME=genesis
ARG GROUP_NAME=genesis
ARG USER_ID
ARG GROUP_ID

FROM nvcr.io/nvidia/cuda:${CUDA_VERSION}-cudnn-devel-ubuntu24.04 AS builder

# ----------------------------------------------------------
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
    ## rosdep initialize
    && rosdep init && rosdep update \
    ## clean up
    && apt clean \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------
# ---- Create a non-root user ------------------------------
# ubuntu(uid=1000) user exists in the base image. But uid may
# conflict with the host user id. So, we delete the ubuntu user.
RUN userdel -r ubuntu || true \
    && groupdel ubuntu || true \
    && groupadd --gid ${GROUP_ID} ${GROUP_NAME} \
    && useradd --shell /bin/bash -u ${USER_ID} -g ${GROUP_ID} -m ${USER_NAME}


# ----------------------------------------------------------
# ---- Install Genesis -------------------------------------
ENV PIP_NO_CACHE_DIR=1 \
    PIP_BREAK_SYSTEM_PACKAGES=1

USER ${USER_NAME}
COPY --chown=${USER_NAME}:${GROUP_NAME} libs/Genesis /tmp/Genesis
RUN pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu130 \
    && pip install PyOpenGL==3.1.5 \
    && pip install /tmp/Genesis \
    && pip install open3d numpy==1.26.4 \
    && rm -rf /tmp/Genesis


# ----------------------------------------------------------
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


# ----------------------------------------------------------
# ---- Create workspace structure --------------------------
RUN mkdir -p /workspace  \
    && cd /workspace \
    && mkdir build install src \
    && chown -R ${USER_NAME}:${GROUP_NAME} /workspace

USER ${USER_NAME}
WORKDIR /workspace
