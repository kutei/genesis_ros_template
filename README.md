mkdir -p ros2_ws/src; cd $_; git clone https://github.com/vybhav-ibr/genesis_ros.git
cd ../
source /opt/ros/jazzy/setup.bash
colcon build

cd /workspace
git clone https://github.com/Genesis-Embodied-AI/Genesis.git

pip install numpy==1.26.4
