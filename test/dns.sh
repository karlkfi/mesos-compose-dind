#!/usr/bin/env bash

# Wait for Mesos-DNS to resolve cluster components.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

probe_until_ready "http://leader.mesos:5050/health"
probe_until_ready "http://marathon.mesos:8080/ping"
