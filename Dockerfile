ARG CUDA_VERSION=13.0.2
ARG PYTORCH_VERSION=2.9.1
ARG CUDNN_VERSION=9

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
    ## rosdep initialize
    && rosdep init && rosdep update \
    ## clean up
    && apt clean \
    && rm -rf /var/lib/apt/lists/*


# ----------------------------------------------------------
# ---- Install Genesis -------------------------------------
RUN export PIP_NO_CACHE_DIR=1 \
    && pip install open3d PyOpenGL==3.1.5 \
    && pip install torch==2.9.1 torchvision==0.24.1 torchaudio==2.9.1 --index-url https://download.pytorch.org/whl/cu130 \
    && git clone https://github.com/Genesis-Embodied-AI/Genesis.git /tmp/Genesis \
    && pip install /tmp/Genesis \
    && rm -rf /tmp/Genesis
