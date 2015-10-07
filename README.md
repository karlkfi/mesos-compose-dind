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

### Prerequisites

Required:
- [Docker CLI](https://docs.docker.com/) - container management command line client
- [Docker Engine](https://docs.docker.com/) - container management daemon
  - On Mac, use [Boot2Docker](http://boot2docker.io/) or [Docker Machine](https://docs.docker.com/machine/install-machine/)
- [Docker Compose](https://docs.docker.com/compose/install/) - multi-container application orchestration
- [Probe](https://github.com/karlkfi/probe) (&gt;= 0.2.0) - command-line service interrogator
  - Compile with `go get github.com/karlkfi/probe` or `brew install probe` ([custom formula](https://github.com/karlkfi/probe#with-homebrew))
- [Wget](http://www.gnu.org/software/wget/) - command-line http client

Optional:
- [Virtual Box](https://www.virtualbox.org/wiki/Downloads) - x86 hardware virtualizer
  - Required by Boot2Docker and Docker Machine

#### Install on Mac (Homebrew)

It's possible to install all of the above via [Homebrew](http://brew.sh/) on a Mac.

Some steps print instructions for configuring or launching. Make sure each is properly set up before continuing to the next step.

```
brew install caskroom/cask/brew-cask
brew cask install virtualbox
brew install docker
brew install boot2docker
boot2docker init
boot2docker up
brew install docker-compose
brew install wget
```

See [Probe](https://github.com/karlkfi/probe) for installation instructions.


#### Install on Linux

Most of the above are available via apt and yum, but depending on your distribution, you may have to install via other
means to get the latest versions.

It is recommended to use Ubuntu, simply because it supports OverlayFS, used by docker to mount volumes. Alternate file
systems may not fully support docker-in-docker.

#### Boot2Docker Config (Mac)

If on a mac using boot2docker, the following steps will make the docker IPs (in the virtualbox VM) reachable from the
host machine (mac).

1. Set the VM's host-only network to "promiscuous mode":

    ```
    boot2docker stop
    VBoxManage modifyvm boot2docker-vm --nicpromisc2 allow-all
    boot2docker start
    ```

    This allows the VM to accept packets that were sent to a different IP.

    Since the host-only network routes traffic between VMs and the host, other VMs will also be able to access the docker
    IPs, if they have the following route.

1. Route traffic to docker through the boot2docker IP:

    ```
    sudo route -n add -net 172.17.0.0 $(boot2docker ip)
    ```

    Since the boot2docker IP can change when the VM is restarted, this route may need to be updated over time.
    To delete the route later: `sudo route delete 172.17.0.0`


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
sudo ./bin/dns-update.sh 172.17.42.1
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
