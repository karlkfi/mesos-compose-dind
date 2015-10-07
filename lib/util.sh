#!/usr/bin/env bash

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root=$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd)

source "${project_root}/env.sh"


# Execute a docker-compose command with the default environment and compose file.
function util::docker_compose {
  local params="$@"

  # All vars required to be set
  declare -a env_vars=(
    "MCD_WORK_DIR"
    "MCD_LOG_DIR"
    "MCD_DNS_CONFIG_PATH"
    "DOCKER_DAEMON_ARGS"
  )

  (
    for var_name in "${env_vars[@]}"; do
      export ${var_name}="${!var_name}"
    done

    docker-compose -p "mcd" -f "${project_root}/docker-compose.yaml" ${params}
  )
}

# Pull the images from a docker compose file, if they're not already cached.
# This avoid slow remote calls from `docker-compose pull` which delegates
# to `docker pull` which always hits the remote docker repo, even if the image
# is already cached.
function util::docker_compose_lazy_pull {
  for img in $(grep '^\s*image:\s' "${project_root}/docker-compose.yaml" | tr '\t' ' ' | sed 's/ *image: *//'); do
    read repo tag <<<$(echo "${img} "| sed 's/:/ /')
    if [ -z "${tag}" ]; then
      tag="latest"
    fi
    if ! docker images "${repo}" | awk '{print $2;}' | grep -q "${tag}"; then
      docker pull "${img}"
    fi
  done
}

function util::docker_compose_services {
  grep '^\w*:' "${project_root}/docker-compose.yaml" | sed 's/://'
}

# Lookup docker-compose service IP(s)
function util::find_docker_service_ips {
  local service="$1"
  local docker_ids=$(docker ps --filter="label=com.docker.compose.service=${service}" --quiet)
  if [ -z "${docker_ids}" ]; then
    echo "ERROR: Container '${service}' not running" 1>&2
    return 1
  fi
  while read -r docker_id; do
    local host=$(docker inspect --format="{{.NetworkSettings.IPAddress}}" "${docker_id}")
    echo "${host}"
  done <<< "${docker_ids}"
}

# Lookup docker-compose service hosts(s)
function util::find_docker_service_host {
  local service="$1"
  local docker_ids=$(docker ps --filter="label=com.docker.compose.service=${service}" --quiet)
  if [ -z "${docker_ids}" ]; then
    echo "ERROR: Container '${service}' not running" 1>&2
    return 1
  fi
  while read -r docker_id; do
    local host=$(docker inspect --format="{{.Config.Hostname}}.{{.Config.Domainname}}" "${docker_id}")
    echo "${host}"
  done <<< "${docker_ids}"
}

function util::dump_logs {
  local out_dir="$1"
  echo "Dumping logs to '${out_dir}'" 1>&2
  mkdir -p "${out_dir}"
  while read name; do
    docker logs "${name}" &> "${out_dir}/${name}.log"
  done < <(util::docker_compose ps -q | xargs docker inspect --format '{{.Name}}')
}

function util::await_cluster {
  local exhibitor_ip="$(util::find_docker_service_ips "zookeeper" | tail -1)"
  echo "Exhibitor UI: http://${exhibitor_ip}:8080/exhibitor/v1/ui/index.html" 1>&2

  local master_ip="$(util::find_docker_service_ips "mesosmaster" | tail -1)"
  echo "Mesos UI (Master): http://${master_ip}:5050" 1>&2

  local mesosdns_ip="$(util::find_docker_service_ips "mesosdns" | tail -1)"
  echo "Mesos-DNS: http://${mesosdns_ip}:8123" 1>&2

  local slave_ips="$(util::find_docker_service_ips "mesosslave")"
  while read -r slave_ip; do
     echo "Mesos Slave: http://${slave_ip}:5051" 1>&2
  done <<< "${slave_ips}"

  local marathon_ip="$(util::find_docker_service_ips "marathon" | tail -1)"
  echo "Marathon UI: http://${marathon_ip}:8080" 1>&2

  probe_until_ready "http://${exhibitor_ip}:8080/exhibitor/v1/cluster/status"
  probe_until_ready "http://${master_ip}:5050/health"
  probe_until_ready "http://${mesosdns_ip}:8123/v1/version"
  while read -r slave_ip; do
     probe_until_ready "http://${slave_ip}:5051/health"
  done <<< "${slave_ips}"
  probe_until_ready "http://${marathon_ip}:8080/ping"
}

function probe_until_ready {
  local address="$1"
  local timeout="${2:-${MCD_READY_TIMEOUT}}"
  echo "Probing \"${address}\" until ready..." 1>&2
  set +o errexit
  probe --max-attempts=-1 --retry-delay=1s --timeout="${timeout}s" --attempt-timeout=30s "${address}"
  local exit_code="$?"
  set -o errexit
  if [ "${exit_code}" != "0" ]; then
    echo "Probing Failed!" 1>&2
    return ${exit_code}
  fi
  echo "Probing Suceeded!" 1>&2
}
