# Global variables ------------------------------------------------------------

LOG_DIR := $(abspath logs)

# rule dependencies -----------------------------------------------------------

all: tox stack

tox: devstack-tox networking-odl-tox

stack: control compute

clean: destroy

devstack: devstack-tox control

networking-odl: networking-odl-tox control

control: control-up

compute: compute-up

control-up compute-up: box-update

.PHONY: clean destroy compute compute-up control control-up box-update\
    networking-odl networking-odl-tox devstack devstack-tox

# rules details ---------------------------------------------------------------

devstack-tox: $(LOG_DIR)
	cd devstack && tox -v  # $@
	
networking-odl-tox: $(LOG_DIR)
	cd networking-odl && tox -v  # $@

box-update: $(LOG_DIR)
	vagrant box update || true  # $@

control-up: $(LOG_DIR)
	vagrant up --provider virtualbox control  # $@

compute-up: $(LOG_DIR)
	vagrant up --provider virtualbox compute  # $@

control: $(LOG_DIR)
	$(call VAGRANT_SSH,$@,cd /opt/stack/devstack && ./unstack.sh) || true  # $@ unstack
	vagrant reload $@  # $@ reboot
	$(call VAGRANT_SSH,$@,cd /opt/stack/devstack && ./stack.sh)  # $@ stack

compute: $(LOG_DIR)
	$(call VAGRANT_SSH,$@,cd /opt/stack/devstack && ./unstack.sh) || true  # $@ unstack
	vagrant reload $@  # $@ reboot
	-$(call VAGRANT_SSH,$@,wget control:5000)  # $@ check-connectivity
	$(call VAGRANT_SSH,$@,cd /opt/stack/devstack && ./stack.sh)  # $@ stack

clean:
	rm -fR .vagrant .tox

destroy:
	vagrant destroy -f
	rm -fR $(LOG_DIR)

$(LOG_DIR):
	mkdir -p "$@"

# Functions -------------------------------------------------------------------

SHELL := scripts/shell

VAGRANT_SSH = vagrant ssh "$1" -c '$2'

