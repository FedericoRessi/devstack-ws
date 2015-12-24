LOG_DIR = logs
LOG_FILE = $(abspath $(LOG_DIR)/$(1).log)

SHELL := /bin/bash

all: tox-networking-odl control compute

control: control-up

compute: control compute-up

control-up compute-up: update-boxes

update-boxes tox-networking-odl control-up compute-up: $(LOG_DIR)


tox-networking-odl:
	cd networking-odl && tox -v > $(call LOG_FILE,01-host-$@) 2>&1

update-boxes:
	vagrant box update > $(call LOG_FILE,02-host-update-boxes) 2>&1 || true

control-up:
	vagrant up control > $(call LOG_FILE,02-control-up) 2>&1

compute-up:
	vagrant up compute > $(call LOG_FILE,02-compute-up) 2>&1

control:
	vagrant ssh control -c "cd /opt/stack/devstack && ./unstack.sh" > $(call LOG_FILE,03-control-unstack) 2>&1 || true
	# make sure it uses the last kernel
	vagrant reload control > $(call LOG_FILE,04-control-reboot) 2>&1
	vagrant ssh control -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,05-control-stack) 2>&1

compute:
	# test connectivity with control node
	vagrant ssh compute -c 'wget control:5000 -o /dev/null' > $(call LOG_FILE,02-test-connectivityk) 2>&1
	vagrant ssh compute -c "cd /opt/stack/devstack && ./unstack.sh" > $(call LOG_FILE,03-compute-unstack) 2>&1 || true
	# make sure it uses the last kernel
	vagrant reload compute > $(call LOG_FILE,04-compute-reboot) 2>&1
	vagrant ssh compute -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,05-compute-stack) 2>&1

destroy:
	vagrant destroy -f
	rm -fR $(LOG_DIR)

clean: destroy
	rm -fR .vagrant .tox

$(LOG_DIR):
	mkdir -p "$@"

.PHONY: clean compute compute-up control control-up update-boxes tox-networking-odl
