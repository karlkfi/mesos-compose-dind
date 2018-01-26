#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

echo "Cleaning Log Dir" 1>&2
rm -rf "${MCD_LOG_DIR}"/*

# Pull before `docker-compose up` to avoid timeouts caused by slow pulls during deployment.
echo "Pulling Docker images" 1>&2
util::docker_compose_lazy_pull

# Dump logs on exit
trap "util::dump_logs '${MCD_LOG_DIR}/start'" EXIT

echo "Starting Cluster" 1>&2
util::docker_compose start

echo "Scaling Cluster to ${MCD_NUM_SLAVES} slaves" 1>&2
util::docker_compose scale mesosslave=${MCD_NUM_SLAVES}

util::await_cluster

echo "Cluster Started" 1>&2
echo "Run 'sudo ./bin/dns-update.sh $(util::find_docker_service_ips "mesosdns" | tail -1)' to add Mesos-DNS as a nameserver, if desired." 1>&2
