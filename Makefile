LOG_DIR = logs
LOG_FILE = $(abspath $(LOG_DIR)/$(1).log)

SHELL := /bin/bash

all: tox-networking-odl control compute

control: control-up

compute: control compute-up

# control-up compute-up: update-boxes

update-boxes tox-networking-odl: $(LOG_DIR)


update-boxes:
	vagrant box update > $(call LOG_FILE,01-host-update-boxes) 2>&1

control-up:
	vagrant up control > $(call LOG_FILE,01-control-up) 2>&1

tox-networking-odl:
	cd networking-odl && tox -v > $(call LOG_FILE,01-host-$@) 2>&1

control:
	vagrant ssh control -c "cd /opt/stack/devstack && ./unstack.sh" || true > $(call LOG_FILE,03-control-unstack) 2>&1
	vagrant ssh control -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,04-control-stack) 2>&1

compute-up:
	vagrant up compute > $(call LOG_FILE,01-compute-up) 2>&1

compute:
	# test connectivity with control node
	vagrant ssh compute -c 'wget control:5000 -o /dev/null' > $(call LOG_FILE,02-test-connectivityk) 2>&1
	vagrant ssh compute -c "cd /opt/stack/devstack && ./unstack.sh" || true > $(call LOG_FILE,03-compute-unstack) 2>&1
	# make sure it uses last kernel
	vagrant reload compute > $(call LOG_FILE,04-compute-reboot) 2>&1
	vagrant ssh compute -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,05-compute-stack) 2>&1

clean:
	vagrant destroy -f
	rm -fR $(LOG_DIR) .vagrant .tox

$(LOG_DIR):
	mkdir -p "$@"

.PHONY: clean compute compute-up control control-up update-boxes tox-networking-odl