daolinet安装文档
==========

此文档描述daolinet在CentOS7和最新Fedora系统中的安装过程，对于Ubuntu和Debian发行版系统，需要将以下文档中所有使用yum包管理工具的地方替换为apt-get。

以下详细介绍daolinet安装环境准备和集群安装过程。

安装环境
----------

daolinet使用docker swarm原生集群工具进行容器管理，在集群环境安装daolinet至少需要一个manager节点和一个agent节点。

安装daolinet前，所有节点必须准备如下环境：

* Docker Version 1.9 or later
* Git
* Python 2.7
* Golang Version 1.5 or later

#### 安装依赖

* Linux快速安装docker使用如下命令安装，详细安装请参考[On Linux distributions](https://docs.docker.com/engine/installation/linux/)

		curl -fsSL https://get.docker.com/ | sh

* 安装Golang环境可以通过如下步骤进行，详细安装请参考[Go Getting Started](https://golang.org/doc/install)

		wget https://storage.googleapis.com/golang/go1.5.3.linux-amd64.tar.gz
		tar xzvf go1.5.3.linux-amd64.tar.gz -C /usr/local/
		export PATH=$PATH:/usr/local/go/bin

* 安装其它依赖的软件开发包

		yum install -y git epel-release
		yum install -y python-devel git python-pip

> ***注意：***
>
> 1. 文档中所有export命令都可以配置到profile文件中永久生效
>
> 2. 所有节点添加如下iptables规则允许内网其它节点可以访问：

>			iptables -I INPUT -s <SUBNET>/<PREFIX> -j ACCEPT

集群安装
-----------

### 部署manager节点

在manager节点需要安装以下与daolinet相关组件和工具：

* etcd (键值存储/服务发现)
* swarm manager (docker集群manager服务)
* ryu (openflow框架)
* daolinet (daolinet api服务)
* daolictl (daolinet命令行工具)
* daolicontroller (openflow控制器)

以下详细说明manager节点安装过程

#### 1. 安装etcd

	docker pull microbox/etcd
	docker run -ti -d -p 4001:4001 -p 7001:7001 --restart=always --name discovery microbox/etcd -addr <SWARM-IP>:4001 -peer-addr <SWARM-IP>:7001

#### 2. 安装swarm manager

	docker pull swarm
	docker run -ti -d -p 3376:3376 --restart=always --name swarm-manager --link discovery:discovery swarm m --addr <SWARM-MANAGER-IP>:3376 --host tcp://0.0.0.0:3376 etcd://discovery:4001

#### 3. 编译安装daolinet api server

	mkdir $HOME/daolinet
	cd $HOME/daolinet
	export GOPATH=$HOME/daolinet
	go get github.com/tools/godep
	export PATH=$PATH:$GOPATH/bin
	mkdir -p src/github.com/daolicloud
	cd src/github.com/daolicloud
	git clone https://github.com/daolicloud/daolinet.git
	cd daolinet
	godep go build
	mv daolinet ../../../../bin/

	# Run api server
	daolinet server --swarm tcp://<SWARM-MANAGER-IP>:3376 etcd://<ETCD-IP>:4001

#### 4. 编译安装daolictl命令行工具

接着第三步环境继续进行daolictl的编译和安装

	cd $HOME/daolinet/src/github.com/daolicloud
	git clone https://github.com/daolicloud/daolictl.git
	cd daolictl
	godep go build
	mv daolictl ../../../../bin/

#### 5. 安装openflow控制器

	# Install openflow framework
	pip install ryu
	# Install depend packages
	yum install -y python-requests python-docker-py
	# Install openflow controller
	git clone https://github.com/daolicloud/daolicontroller.git
	cd daolicontroller; python ./setup.py install
	# Run daolicontroller
	daolicontroller

### 部署agent节点

agent节点需要安装与daolinet相关组件和其它软件：

* openvswitch (virtual switch)
* swarm agent (docker集群agent)
* daolinet (daolinet agent服务)
* ovsplugin (daolinet ovs插件)

以下详细说明agent节点安装步骤

#### 1. 配置docker启动参数

修改docker daemon启动参数，添加swarm管理和etcd支持。例如在CentOS7下修改/usr/lib/systemd/system/docker.service文件中如下ExecStart参数：

	ExecStart=/usr/bin/docker daemon -H fd:// -H tcp://0.0.0.0:2375 --cluster-store=etcd://<ETCD-IP>:4001

然后重启服务：

	systemctl daemon-reload
	systemctl restart docker.service

#### 2. 安装swarm agent

	docker pull swarm
	docker run -ti -d --restart=always --name swarm-agent swarm j --addr <SWARM-AGENT-IP>:2375 etcd://<ETCD-IP>:4001

#### 3. 安装配置openvswitch

OpenVswitch安装过程请执行以下命令，详细安装请参考[How to Install Open vSwitch on Linux, FreeBSD and NetBSD](https://github.com/openvswitch/ovs/blob/master/INSTALL.md)

	# 编译openvswitch源码
	yum install -y openssl-devel rpm-build
	wget http://openvswitch.org/releases/openvswitch-2.5.0.tar.gz
	mkdir -p ~/rpmbuild/SOURCES
	cp openvswitch-2.5.0.tar.gz ~/rpmbuild/SOURCES/
	tar xzf openvswitch-2.5.0.tar.gz
	rpmbuild -bb --without check openvswitch-2.5.0/rhel/openvswitch.spec

	# 安装生成的软件包
	yum localinstall -y rpmbuild/RPMS/x86_64/openvswitch-2.5.0-1.x86_64.rpm
	/etc/init.d/openvswitch start

如果通过控制台登录Linux系统，以下操作可能会导致控制台退出或不能连接服务器等情况，请将以下`<DEVNAME>、<DEVIP>、<DEVMAC>、<GATEWAYIP>`变量指定正确后写入脚本执行，否则可以直接执行。

	# 配置ovs网桥
	systemctl stop NetworkManager
	systemctl disable NetworkManager
	ovs-vsctl add-br daolinet
	ovs-vsctl add-port daolinet <DEVNAME>eno16777728
	ovs-vsctl add-port daolinet eno16777728
	ip addr del <DEVIP> dev <DEVNAME>
	ip addr change <DEVIP> dev <DEVNAME>
	ovs-vsctl set Bridge daolinet other_config:hwaddr="<DEVMAC>"
	# 如果<DEVNAME>作为缺省网关，则需要执行以下命令
	ip route add default via <GATEWAYIP>

#### 4. 安装ovs plugin

	pip install gunicorn flask netaddr
	git clone https://github.com/daolicloud/ovsplugin.git
	cd ovsplugin/
	./start.sh

#### 5. 安装daolinet agent

如果agent节点与manager节点操作系统环境一样，此步中daolinet可以直接拷贝`部署manager节点`步骤时编译完成的二进制文件；如果系统环境不一样，此步中daolinet直接按照`部署manager节点` -> `编译安装daolinet api server`步骤完成编译，再执行以下命令启动agent服务：

	daolinet agent --iface <DEVNAME:DEVIP> etcd://<ETCD-IP>:4001

#### 6. 连接控制器

在agent节点完成以上步骤，最后配置ovs连接到daolicontroller控制器：

	ovs-vsctl set-controller daolinet tcp:<CONTROLLER-IP>:6633

***注意：***为了提高系统可用性，集群中可以启动多个daolicontroller控制器，同时在配置ovs时指定多个控制器地址:

	ovs-vsctl set-controller daolinet tcp:<CONTROLLER-IP1>:6633,tcp:<CONTROLLER-IP2>:6633

## 总结

以上为daolinet安装过程，下一步，如何使用daolinet管理docker容器，请参考[用户使用手册](../../../daolictl/blob/master/UserGuide.md)。

