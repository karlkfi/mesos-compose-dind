# Mesos Compose Docker-in-Docker

This is a [docker-compose](https://github.com/docker/compose) cluster that uses [mesos-slave-dind](https://hub.docker.com/r/mesosphere/mesos-slave-dind/) to collocate multiple slave nodes, each with their own docker daemon and /24 network allocation.


### Cluster Topology

The cluster consists of several docker containers linked together by docker-managed hostnames:

| Component             | Hostname                                       | Description                                     |
|-----------------------|------------------------------------------------|-------------------------------------------------|
| Zookeeper + Exhibitor | zookeeper                                      | key/value store w/ process monitor & web gui    |
| Mesos Master          | mesosmaster<br/>master0.mesos<br/>leader.mesos | resource manager w/ web gui                     |
| Mesos-DNS             | mesosdns                                       | dns for mesos components, frameworks, and tasks |
| Mesos Slave (x2)      | mesosslave<br/>slave0.mesos<br/>slave1.mesos   | resource owner                                  |
| Marathon              | marathon.mesos                                 | resource scheduler & container PaaS             |


### Install on Mac

1. Install [Docker For Mac](https://www.docker.com/docker-mac)

2. Install [wget](http://www.gnu.org/software/wget/)

    ```
    brew install wget
    ```

3. Install [probe](https://github.com/karlkfi/probe)

    ```
    brew tap karlkfi/homebrew-terminal
    brew install probe
    ```

### Install on Linux

- [Docker CLI](https://docs.docker.com/) - container management command line client
- [Docker Engine](https://docs.docker.com/) - container management daemon
- [Docker Compose](https://docs.docker.com/compose/install/) - multi-container application orchestration
- [Probe](https://github.com/karlkfi/probe) (&gt;= 0.2.0) - command-line service interrogator
- [Wget](http://www.gnu.org/software/wget/) - command-line http client

Most of the above are available via apt and yum, but depending on your distribution, you may have to install via other
means to get the latest versions.

It is recommended to use Ubuntu, simply because it supports OverlayFS, used by docker to mount volumes. Alternate file
systems may not fully support docker-in-docker.


### Configuration

Most configuration is contained in the [docker-compose.yaml](./docker-compose.yaml) file.

Mesos-DNS is configured by [mesos-dns-config.json](./mesos-dns-config.json).

Some other details (e.g. number of slaves) can be modified with environment variables. See [env.sh](./env.sh) for details.


### Usage

Create a new cluster:

```
./bin/create.sh
```

Stop a running cluster:

```
./bin/stop.sh
```

Start a stopped cluster:

```
./bin/start.sh
```

Destroy a running or stopped cluster:

```
./bin/destroy.sh
```


### DNS Config

In order to allow resolution of domain names on your host machine, mesos-dns need to be added as a nameserver.


#### Add Nameserver

```
sudo ./bin/dns-update.sh $(source lib/util.sh && util::find_docker_service_ips "mesosdns" | tail -1)
```

WARNING: This can be done before or after create, but will slow down host domain name resolution if mesos-dns is not running.


#### Remove Nameserver

This will remove the extra nameserver and leave the original one.

```
sudo ./bin/dns-update.sh
```

WARNING: Macs normally use auto-updating DNS, which is disabled as a side effect of dns-update. To restore auto-updates on network change: delete all DNS records in `System Preferences > Network > [current network] > Advanced > DNS`.


### Tests

To verify Mesos-DNS (after running dns-update) run:

```
./test/dns.sh
```

To verify Marathon (after running dns-update) run:

```
./test/marathon.sh
```

### User Interfaces

Mesos UI is accessible on port 5050. Get the IP on the command-line:

```
docker inspect -f '{{.NetworkSettings.IPAddress}}:5050' mcd_mesosmaster_1
```

Marathon UI is accessible on port 8080. Get the IP on the command-line:

```
docker inspect -f '{{.NetworkSettings.IPAddress}}:8080' mcd_marathon_1
```

Exhibitor UI is accessible on port 8080. Get the IP on the command-line:

```
docker inspect -f '{{.NetworkSettings.IPAddress}}:8080/exhibitor/v1/ui/index.html' mcd_zookeeper_1
```


### License

Copyright 2015-2018 [The Mesos Compose Docker-in-Docker Authors](./AUTHORS.md)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
