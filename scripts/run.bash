#!/bin/bash -eu

repo_dir=$(readlink -f $(dirname $0)/..)

# Build Docker image
export USER_ID=$(id -u)
export GROUP_ID=$(id -g)
docker compose \
    --file $repo_dir/docker-compose.yaml \
    --project-directory $repo_dir \
    run --rm -it genesis_ros "$@"
