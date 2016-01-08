# Global variables ------------------------------------------------------------

BUILD_NUMBER ?= 0
BUILD_DIR ?= $(abspath build/$(BUILD_NUMBER))
export LOG_DIR := $(BUILD_DIR)/logs

# bash wrapper that redirects stout and sterr to log files
SHELL := scripts/shell

GIT := git

GERRIT_PROJECT ?= ""

all: tox stack

GERRIT_BASE = `../scripts/valuefromini .gitreview gerrit defaultbranch master`


# -----------------------------------------------------------------------------

tox: tox-devstack tox-networking-odl

tox-devstack: $(BUILD_DIR)
	cd devstack && tox -v  # $@

tox-networking-odl: $(BUILD_DIR)
	cd networking-odl && tox -v  # $@

$(BUILD_DIR):
	mkdir -p $(LOG_DIR);\
	ln -sfn $(LOG_DIR) ./logs

# -----------------------------------------------------------------------------

stack: stack-control stack-compute

stack-control: boot-control
	vagrant ssh control -c 'cd /opt/stack/devstack && ./stack.sh'  # $@

stack-compute: boot-compute
	-vagrant ssh compute -c 'wget control:5000'  # $@ check-connectivity
	vagrant ssh compute -c 'cd /opt/stack/devstack && ./stack.sh'  # $@

boot-control: $(BUILD_DIR)
	vagrant up control --no-provision &&\
	vagrant provision control && (\
	vagrant ssh control -c '\
		cd /opt/stack/devstack &&\
		./unstack.sh;\
		rm -fr /opt/stack/logs/*';\
	vagrant reload control)  # $@

boot-compute: $(BUILD_DIR)
	vagrant up compute --provision &&\
	vagrant provision compute && (\
	vagrant ssh compute -c '\
		cd /opt/stack/devstack &&\
		./unstack.sh;\
		rm -fr /opt/stack/logs/*';\
	vagrant reload compute)  # $@

# -----------------------------------------------------------------------------

clean: clean-cache destroy
	rm -fR $(BUILD_DIR) $(LOG_DIR)  # $@

clean-cache:
	rm -fR .vagrant */.tox  # $@

destroy: destroy-control destroy-compute

destroy-control:
	rm -fR $(BUILD_DIR)/logs/control;\
	vagrant destroy -f control;  # $@

destroy-compute:
	rm -fR $(BUILD_DIR)/logs/compute;\
	vagrant destroy -f compute;  # $@

# -----------------------------------------------------------------------------

jenkins: update-box checkout-patchset
	$(MAKE) tox stack-control  # $@

update-box: $(BUILD_DIR)
	vagrant box outdated 2>&1 | grep 'vagrant box update' && (\
	vagrant box update;\
	$(MAKE) destroy) || true # $@

update-submodules: $(BUILD_DIR)
	$(GIT) submodule sync &&\
	$(GIT) submodule update --init --remote --recursive &&\
	$(GIT) submodule foreach '\
		set -ex;\
		$(GIT) review -vs;\
		$(GIT) rebase $(GERRIT_BASE);\
		$(GIT) tag -af INTEGRATION_BASE -m "Base revision for integration.";\
	'  # $@

checkout-patchset: update-submodules
	if [ -n "$(GERRIT_PROJECT)" ]; then\
		set -ex;\
	    cd "$(GERRIT_PROJECT)";\
		$(GIT) review -vd $(GERRIT_CHANGE_NUMBER)/$(GERRIT_PATCHSET_NUMBER);\
		$(GIT) rebase INTEGRATION_BASE;\
	fi # $@
