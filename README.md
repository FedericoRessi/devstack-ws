Simple workspace for running code and tests on vagrant provisioned VM

## Goal

Prepare workspace toolset for working with devstack and vagrant. 

## Implemented features
* Support multiple [Linux distributions](docs/features/linux-distributions.md)
* Provide VMs with [devstack dependencies](docs/features/devstack-dependencies.md)
* [Deploy OpenStack](docs/features/deploy-openstack.md) repos to /opt/stack
* Provide [proxy auto-confguration](docs/features/proxy-autoconf.md)

## Planned features
* Integrate with autoenv ([issue #1](https://github.com/FedericoRessi/devstack-ws/issues/1))
* Run stack.sh in VM ([issue #2](https://github.com/FedericoRessi/devstack-ws/issues/2))
* Writes log files to workspace directory ([issue #3](https://github.com/FedericoRessi/devstack-ws/issues/3))
* Run tox on vagrant: PLANNED
* Support GIT subrepos: PLANNED
* Run on jenkins: PLANNED
* Support offline mode with local mirrors: PLANNED
* Framework for vagrant based test cases: PLANNED
* Jenkins multi-step build: PLANNED
* Cloud VMs build: PLANNED
