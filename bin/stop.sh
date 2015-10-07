#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

echo "Stopping Cluster" 1>&2
util::docker_compose stop

echo "Cluster Stopped" 1>&2
echo "Run 'sudo ./bin/dns-update.sh' to remove Mesos-DNS as a nameserver, if desired." 1>&2
