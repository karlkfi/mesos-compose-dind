#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

echo "Cleaning Log Dir" 1>&2
rm -rf "${MCD_LOG_DIR}"/*

echo "Cleaning Work Dir" 1>&2
rm -rf "${MCD_WORK_DIR}"/*

# Pull before `docker-compose up` to avoid timeouts caused by slow pulls during deployment.
echo "Pulling Docker images" 1>&2
util::docker_compose_lazy_pull

# Dump logs on exit
trap "util::dump_logs '${MCD_LOG_DIR}/create'" EXIT

echo "Starting Cluster" 1>&2
util::docker_compose up -d

echo "Scaling Cluster to ${MCD_NUM_SLAVES} slaves" 1>&2
util::docker_compose scale mesosslave=${MCD_NUM_SLAVES}

util::await_cluster

echo "Cluster Created" 1>&2
echo "Run 'sudo ./bin/dns-update.sh 172.17.42.1' to add Mesos-DNS as a nameserver, if desired." 1>&2
