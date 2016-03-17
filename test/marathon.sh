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

function test::nginx_address {
  wget -SO - "http://${marathon_ip}:8080/v2/apps/nginx?embed=apps.counts" | jq '.app.tasks[0] | "\(.host):\(.ports[0])"' --raw-output
}

# marathon updates the apps data pretty quickly, but not before returning from the creation request
for i in {1..30}; do
  app_address="$(test::nginx_address)"
  if [ "${app_address}" != "null:null" ]; then
    break
  fi
  sleep 2
done
#app_address="nginx.marathon.mesos"
if [ "${app_address}" == "null" ]; then
  echo "Timed out waiting for Nginx App to deploy!" 1>&2
  exit 2
fi

echo "Nginx App: http://${app_address}/" 1>&2

# once app is created, it may take a while to be ready (esp if downloading the docker image)
probe_until_ready "http://${app_address}/" 120

echo "Deleting Nginx App" 1>&2
wget -SO - --method=DELETE http://${marathon_ip}:8080/v2/apps/nginx

echo "Test Passed!" 1>&2
