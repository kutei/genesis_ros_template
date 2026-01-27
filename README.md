# genesis_ros_template

This is a template repository for Genesis simulator integrated with ROS2.

## How to Use

- build docker image
    ```bash
    ./scripts/build.bash
    ```

- start docker container
    ```bash
    xhost +
    ./scripts/run.bash
    ```
    or you can pass the command
    ```bash
    xhost +
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
