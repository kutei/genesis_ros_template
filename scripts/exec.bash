#!/bin/bash -eu

repo_dir=$(readlink -f $(dirname $0)/..)

# load configs
source $repo_dir/scripts/config.bash

# run Docker image
if [ $# -eq 0 ]; then
    docker compose \
        --file $repo_dir/docker-compose.yaml \
        --project-directory $repo_dir \
        exec -u $USER_ID -it genesis_ros bash
else
    docker compose \
        --file $repo_dir/docker-compose.yaml \
        --project-directory $repo_dir \
        exec -u $USER_ID -it genesis_ros "$@"
fi
