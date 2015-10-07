#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

# Timeout (in seconds) to wait for each micro-service to be ready after their dependencies are ready
MCD_READY_TIMEOUT="${MCD_READY_TIMEOUT:-30}"

# Path to directory on the host to use as the root for mesos work dir volumes.
# ${MCD_WORK_DIR}/<component> - storage of mesos slave work (e.g. task logs)
# If using docker-machine or boot2docker, should be under /Users (which is mounted from the host into the docker vm).
# If running in a container, $HOME should be resolved outside of the container.
MCD_WORK_DIR="${MCD_WORK_DIR:-${project_root}/tmp/work}"

# Path to directory on the host to use as the root for container stdout/stderr logs.
# ${MCD_LOG_DIR}/<component> - storage of component logs
# If using docker-machine or boot2docker, should be under /Users (which is mounted from the host into the docker vm).
# If running in a container, $HOME should be resolved outside of the container.
MCD_LOG_DIR="${MCD_LOG_DIR:-${project_root}/tmp/logs}"

# Path to json file on the host to configure mesos-dns with.
MCD_DNS_CONFIG_PATH="${MCD_DNS_CONFIG_PATH:-${project_root}/mesos-dns-config.json}"

# Arguments to pass to docker-engine running on the mesos-slave-dind containers.
DOCKER_DAEMON_ARGS="${DOCKER_DAEMON_ARGS:---log-level=error}"

# Number of Mesos slaves to deploy
MCD_NUM_SLAVES="${MCD_NUM_SLAVES:-2}"
