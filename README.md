# genesis_ros_template

This is a template repository for Genesis simulator integrated with ROS2.

## How to Use

- build docker image
    ```bash
    ./scripts/build.bash
    ```

- start docker container
    ```bash
    ./scripts/run.bash
    ```
    or you can pass the command
    ```bash
    ./scripts/run.bash colcon build
    ```

- enter docker container
    ```bash
    ./scripts/exec.bash
    ```
    or you can pass the command
    ```bash
    ./scripts/exec.bash colcon build
    ```

- create a ROS2 package
   ```bash
   ./scripts/run.bash
   ```
   then inside the container
   ```bash
   source /opt/ros/jazzy/setup.bash
   cd src/pkgs
   ros2 pkg create <package_name> --build-type ament_cmake --dependencies rclcpp std_msgs
   ```
