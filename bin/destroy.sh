#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

echo "Destroying Cluster" 1>&2
util::docker_compose kill
util::docker_compose rm -f

echo "Cluster Destroyed" 1>&2
echo "Run 'sudo ./bin/dns-update.sh' to remove Mesos-DNS as a nameserver, if desired." 1>&2
