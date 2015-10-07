#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/lib/util.sh"

marathon_ip="$(util::find_docker_service_ips "marathon" | tail -1)"
#marathon_ip="marathon.mesos"
echo "Marathon: http://${marathon_ip}:8080" 1>&2

echo "Creating Nginx App" 1>&2
wget -SO - \
    --header="Content-Type: application/json" \
    --post-file="${project_root}/test/assets/nginx/marathon.json" \
    http://${marathon_ip}:8080/v2/apps

function test::nginx_host {
  wget -SO - "http://${marathon_ip}:8080/v2/apps/nginx?embed=apps.counts" | jq '.app.tasks[0].host' --raw-output
}

# marathon updates the apps data pretty quickly, but not before returning from the creation request
for i in {1..30}; do
  host="$(test::nginx_host)"
  if [ "${host}" != "null" ]; then
    break
  fi
  sleep 2
done
#host="nginx.marathon.mesos"

# once app is created, it may take a while to be ready (esp if downloading the docker image)
probe_until_ready "http://${host}:80/" 120
