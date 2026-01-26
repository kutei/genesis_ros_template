#!/bin/bash -eu

repo_dir=$(readlink -f $(dirname $0)/..)

# load configs
source $repo_dir/scripts/config.bash

# run Docker image
docker compose \
    --file $repo_dir/docker-compose.yaml \
    --project-directory $repo_dir \
    run --rm -it genesis_ros "$@"
