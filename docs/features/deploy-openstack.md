# Feature

Deploy openstack GIT repos to /opt/stack

## Operations
* Deploys all GIT repositories contained found the worspace root folder to /opt/stack
* Download devstack repository if not found on /opt/stack
* Deploy local.conf to /opt/stack/devstack

## Example of use

Clone this workspace and enter in its folder
```bash
git clone https://github.com/FedericoRessi/devstack-ws.git my_workspace
cd my_workspace
```

Edit [local.conf](../../local.conf) contained in your workspace
```bash
nano local.conf
```

Now clone some git repo inside of it and edit them
```bash
git clone https://git.openstack.org/openstack/networking-odl
cd networking-odl
git fetch https://review.openstack.org/openstack/networking-odl refs/changes/12/215612/23 && git checkout FETCH_HEAD
```

Start a VM based on your [favorite linux distribution](linux-distributions.md), install devstack and its dependencies and deploy a copy of networking-odl:
```bash
vagrant up trusty
```

Read e-mails, take a tea, or goes to scrum meeting ;-)

Then enters in the VM and launch devstack.
```bash
vagrant ssh trusty
cd /opt/stack/devstack
./stack.sh
```

Now you can unstack, make some changes on the and deploy again.
```bash
./unstack.sh
exit
nano somefile
vagrant provision trusty
```

Now restack as before or destroy the VM.
```bash
vagrant destroy -f trusty
```
