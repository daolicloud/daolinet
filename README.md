Daolinet
========

Daolinet is core for daolinet, it contains an API server and agent to manage docker network.

#### Installation Requirements

Prepare your golang environment firstly.

* Go Version 1.5 or later
* Git

#### Building and Installing daolinet

    cd src/github.com/daolicloud
    git clone https://github.com/daolicloud/daolinet.git
    cd daolinet
    godep go build
    mv daolinet ../../../../bin/

#### Run daolinet api server

    daolinet server --swarm tcp://<SWARM-MANAGER-IP>:3376 etcd://<ETCD-IP>:4001

#### Run daolinet agent

    daolinet agent --iface <DEVNAME:DEVIP> etcd://<ETCD-IP>:4001

### Detail

[InstallGuide.md](InstallGuide.md)
