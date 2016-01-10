# Global variables ------------------------------------------------------------

BUILD_NUMBER ?= 0
BUILD_DIR ?= $(abspath build/$(BUILD_NUMBER))
export LOG_DIR := $(BUILD_DIR)/logs

# bash wrapper that redirects stout and sterr to log files
SHELL := scripts/shell

GIT := git --no-pager

SUBMODULE = $$(basename $$(pwd))
INTEGRATION_BRANCH = `../scripts/valuefromini ../.gitmodules "submodule \"$(SUBMODULE)\"" branch`

GERRIT_HOST = `../scripts/valuefromini .gitreview gerrit host review.openstack.org`
GERRIT_PORT = 443
GERRIT_URL = "https://$(GERRIT_HOST):$(GERRIT_PORT)/`../scripts/valuefromini .gitreview gerrit project unknown-project`"
GERRIT_BASE = `../scripts/valuefromini .gitreview gerrit defaultbranch master`
GERRIT_PROJECT ?= ""

all: tox stack


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
	vagrant ssh control -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		rm -fr /opt/stack/logs/*;\
		./stack.sh'  # $@

stack-compute: boot-compute
	vagrant ssh compute -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		rm -fr /opt/stack/logs/*;\
		./stack.sh'  # $@

boot-control: $(BUILD_DIR)
	set -xe;\
	vagrant up control --no-provision;\
	vagrant provision control;\
	vagrant ssh control -c '\
		cd /opt/stack/devstack;\
		./unstack.sh;\
		true';\
	vagrant reload control  # $@

boot-compute: $(BUILD_DIR)
	set -xe;\
	vagrant up compute --no-provision;\
	vagrant provision compute;\
	vagrant ssh compute -c '\
		cd /opt/stack/devstack;\
		./unstack.sh;\
		true';\
	vagrant reload compute  # $@

# -----------------------------------------------------------------------------

clean: clean-cache destroy
	rm -fR $(BUILD_DIR) $(LOG_DIR)  # $@

clean-cache:
	rm -fR .vagrant */.tox  # $@

destroy: destroy-control destroy-compute

destroy-control:
	rm -fR $(BUILD_DIR)/logs/control;\
	vagrant destroy -f control  # $@

destroy-compute:
	rm -fR $(BUILD_DIR)/logs/compute;\
	vagrant destroy -f compute  # $@

# -----------------------------------------------------------------------------

jenkins: update-box update-submodules destroy
	set -xe;\
	$(MAKE) checkout-patchset;\
	$(MAKE) tox stack-control  # $@

update-box: $(BUILD_DIR)
	if vagrant box outdated 2>&1 | grep 'vagrant box update'; then\
		$(MAKE) destroy;\
		vagrant box update;\
	fi;\
	true # $@

update-submodules: $(BUILD_DIR)
	set -xe;\
	$(GIT) submodule deinit -f .;\
	$(GIT) submodule sync;\
	$(GIT) submodule update --init --remote --recursive;\
	$(GIT) submodule foreach '\
		set -ex;\
		INTEGRATION_BRANCH=$(INTEGRATION_BRANCH);\
		$(GIT) rebase --abort || true;\
		$(GIT) fetch origin $$INTEGRATION_BRANCH;\
		$(GIT) checkout -f FETCH_HEAD;\
		$(GIT) checkout -B integration/base;\
		if $(GIT) remote | grep gerrit > /dev/null; then\
			$(GIT) remote remove gerrit;\
		fi;\
		$(GIT) remote add -f gerrit $(GERRIT_URL);\
		$(GIT) rebase gerrit/$(GERRIT_BASE)'  # $@

checkout-patchset:
	set -ex;\
	if [ -n "$(GERRIT_PROJECT)" ]; then\
		cd "$(GERRIT_PROJECT)";\
		$(GIT) rebase --abort || true;\
		$(GIT) review -vd $(GERRIT_CHANGE_NUMBER)/$(GERRIT_PATCHSET_NUMBER);\
		$(GIT) rebase integration/base;\
	fi;\
	$(GIT) submodule foreach '\
		echo;\
		$(GIT) log --graph -n 5;\
		echo;\
		echo';\
	sleep 1  # $@
