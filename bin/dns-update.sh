#!/usr/bin/env bash

# Update Docker & Mesos DNS
#
# DNS resolution mesos-dns > [host dns]
# If mesos-dns times out, [host dns] will be queried.
#
# WARNING:
# Some clients (e.g. Google Chrome) will query all DNS servers until an answer is found,
# even if previous DNSs in the list respond with NXDOMAIN (non-existant domain).
# Other clients (e.g. curl, dig, wget) will query the DNS servers in order,
# only proceeding to the next configured DNS if the previous DNS request timed out.
# Because mesos-dns is configured without knowledge of the host's pre-configured DNS,
# once mesos-dns is up (not timing out), domains they cannot resolve will be delegated
# to 8.8.8.8 (Google's public DNS), NOT the host's pre-configured DNS.

set -o errexit
set -o nounset
set -o pipefail
set -o errtrace

project_root="$(cd "$(dirname "${BASH_SOURCE}")/.." && pwd -P)"

source "${project_root}/lib/util.sh"

if [ "$(whoami)" != "root" ]; then
	echo "ERROR: Please run as root or with sudo."
	exit 1
fi

#mesos_dns_ip="$(util::find_docker_service_ips "mesosdns" | tail -1 || echo)"
mesos_dns_ip=${1:-}

# Remove old (docker network) nameservers and add new ones
# TODO: use /etc/resolveconf.d/ when available
function update_dns_linux {
  local ns1="$1"

  local resolve_conf="$(</etc/resolv.conf)"

  echo "Current /etc/resolv.conf:"
  echo -e "${resolve_conf}"

#  local nameservers="$(echo "${resolve_conf}" | grep "nameserver " | sed -E "s/nameserver //g")"

#  local nameservers_inline="$(echo -ne "${nameservers}" | tr "\n" " ")"
#  echo -n "Current DNS: "
#  echo "${nameservers_inline}"
#
#  nameservers="$(strip_docker_ips "${nameservers}")"
#  nameservers="${ns1}\n${nameservers}"
#
#  nameservers_inline="$(echo -ne "${nameservers}" | tr "\n" " ")"
#  echo -n "Updated DNS: "
#  echo "${nameservers_inline}"

  resolve_conf="$(strip_docker_ips "${resolve_conf}")"
  resolve_conf="${ns1}\n${resolve_conf}"

  echo -e "${resolve_conf}" > /etc/resolv.conf

  echo "Updated /etc/resolv.conf:"
  echo -e "${resolve_conf}"
}

# (Mac-only) Remove old (docker network) nameservers and add new ones
function update_dns_mac {
  local ns1="$1"

  local network_service_name="$(primary_service_name)"

  local nameservers="$(networksetup -getdnsservers "${network_service_name}")"

  # Automatic DHCP may result in using the router IP as the DNS
  if [[ "${nameservers}" = "There aren't any DNS Servers set on ${network_service_name}." ]]; then
    # Use router IP as DNS
    nameservers=$(networksetup -getinfo "${network_service_name}" | grep "^Router: " | sed -E "s/Router: //g")
    echo "DHCP Detected. Using Router IP as DNS."
  fi

  local nameservers_inline="$(echo -ne "${nameservers}" | tr "\n" " ")"
  echo -n "Current DNS: "
  echo "${nameservers_inline}"

  nameservers="$(strip_docker_ips "${nameservers}")"
  nameservers="${ns1}\n${nameservers}"

  nameservers_inline="$(echo -ne "${nameservers}" | tr "\n" " ")"
  networksetup -setdnsservers "${network_service_name}" ${nameservers_inline}

  echo -n "Updated DNS: "
  echo "${nameservers_inline}"

  if ! [[ -d "/etc/resolver" ]]; then
    mkdir -p "/etc/resolver"
  fi

  if [[ -f "/etc/resolver/mesos" ]]; then
    local old_ns_inline="$(grep "nameserver " /etc/resolver/mesos | sed -E "s/nameserver //g" | tr "\n" " ")"
    echo "Removing Resolver: *.mesos -> ${old_ns_inline}"
    rm /etc/resolver/mesos
  fi

  if [[ ! -z "${ns1}" ]]; then
    echo "Adding Resolver: *.mesos -> ${ns1}"
    bash -c "echo 'nameserver ${ns1}' > /etc/resolver/mesos"
  fi
}

function strip_docker_ips {
  local input="$1"
  while read -r line; do
    if  [[ ! "${line}" =~ 172\.17\.[0-9]*\.[0-9]* ]]; then
      echo "${line}"
    fi
  done <<< "${input}"
}

# (Mac-only) Query scutil
function scutil_query {
    local key="$1"

    scutil<<EOT
    open
    get ${key}
    d.show
    close
EOT
}

# (Mac-only) Find primary network service name
function primary_service_name {
  service_guid=`scutil_query State:/Network/Global/IPv4 | grep "PrimaryService" | awk '{print $3}'`
  service_name=`scutil_query Setup:/Network/Service/${service_guid} | grep "UserDefinedName" | awk -F': ' '{print $2}'`
  echo "${service_name}"
}


# DNS resolution mesos-dns > [host dns]
# If mesos-dns times out, [host dns] will be queried.
#
# WARNING:
# Some clients (e.g. Google Chrome) will query all DNS servers until an answer is found,
# even if previous DNSs in the list respond with NXDOMAIN (non-existant domain).
# Other clients (e.g. curl, dig, wget) will query the DNS servers in order,
# only proceeding to the next configured DNS if the previous DNS request timed out.
# Because mesos-dns is configured without knowledge of the host's pre-configured DNS,
# once mesos-dns is up (not timing out), domains they cannot resolve will be delegated
# to 8.8.8.8 (Google's public DNS), NOT the host's pre-configured DNS.

if grep -q "macOS" /etc/resolv.conf; then
  # Mac >= v10.12
  update_dns_mac "${mesos_dns_ip}"
  echo
  echo -n "WARNING: DNS is now 'hardcoded' and will not automatically update if you change networks. "
  echo "Delete all DNS records to restore auto-updates."
  echo
  echo "Please reset the DNS cache for changes to take effect."
  echo -e "High Sierra v10.13.x:\t\t???"
elif grep -q "Mac OS X" /etc/resolv.conf; then
  # Mac <= v10.11
  update_dns_mac "${mesos_dns_ip}"
  echo
  echo -n "WARNING: DNS is now 'hardcoded' and will not automatically update if you change networks. "
  echo "Delete all DNS records to restore auto-updates."
  echo
  echo "Please reset the DNS cache for changes to take effect."
  echo -e "Yosemite v10.10.4:\t\tsudo killall -HUP mDNSResponder"
  echo -e "Yosemite v10.10-v10.10.3:\tsudo discoveryutil mdnsflushcache"
  echo -e "Mavericks, Mountain Lion, Lion:\tsudo killall -HUP mDNSResponder"
  echo -e "Leopard, Snow Leopard:\t\tsudo dscacheutil -flushcache"
  echo -e "Panther, Tiger:\t\t\tsudo lookupd -flushcache"
else
  # Linux
  update_dns_linux "${mesos_dns_ip}"
fi
