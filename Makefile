# Global variables ------------------------------------------------------------

BUILD_NUMBER ?= 0
BUILD_DIR ?= $(abspath build/$(BUILD_NUMBER))
export LOG_DIR := $(BUILD_DIR)/logs

# bash wrapper that redirects stout and sterr to log files
SHELL := scripts/shell -v
MAKE := make

GIT := git --no-pager

SUBMODULE = $$(basename $$(pwd))
MODULE_INTEGRATION_BRANCH = `../scripts/valuefromini ../.gitmodules "submodule \"$(SUBMODULE)\"" branch`
MODULE_GERRIT_HOST = `../scripts/valuefromini .gitreview gerrit host review.openstack.org`
MODULE_GERRIT_PORT = 443
MODULE_GERRIT_URL = "https://$(MODULE_GERRIT_HOST):$(MODULE_GERRIT_PORT)/`../scripts/valuefromini .gitreview gerrit project unknown-project`"
MODULE_GERRIT_BASE = `../scripts/valuefromini .gitreview gerrit defaultbranch master`
MODULE_GERRIT_PROJECT = `../scripts/valuefromini .gitreview gerrit project unknown-project`

GERRIT_PROJECT ?= ""
GERRIT_CHANGE_NUMBER ?= ""
GERRIT_PATCHSET_NUMBER ?= ""

all: tox stack


# -----------------------------------------------------------------------------

tox: tox-devstack tox-networking-odl

tox-devstack: $(BUILD_DIR)
	unset PYTHONPATH;\
	set -e;\
	cd devstack;\
	tox  # $@

tox-networking-odl: $(BUILD_DIR)
	unset PYTHONPATH;\
	set -e;\
	cd networking-odl;\
	tox  # $@

$(BUILD_DIR):
	mkdir -p $(LOG_DIR);\
	ln -sfn $(LOG_DIR) ./logs

# -----------------------------------------------------------------------------

create: create-control create-compute

create-control: $(BUILD_DIR)
	set -xe;\
	vagrant status | grep control | grep 'not created' || exit 0;\
	vagrant up control;\
	vagrant reload  # $@

create-compute: $(BUILD_DIR)
	set -xe;\
	vagrant status | grep compute | grep 'not created' || exit 0;\
	vagrant up compute;\
	vagrant reload  # $@

# -----------------------------------------------------------------------------

stack: stack-control stack-compute

stack-control: create-control
	set -xe;\
	vagrant up control;\
	vagrant ssh control -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		./stack.sh'  # $@

stack-compute: create-compute
	set -xe;\
	vagrant up compute;\
	vagrant ssh compute -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		./stack.sh'  # $@

# -----------------------------------------------------------------------------

destroy: destroy-control destroy-compute

destroy-control:
	rm -fR $(BUILD_DIR)/logs/control;\
	vagrant destroy -f control  # $@

destroy-compute:
	rm -fR $(BUILD_DIR)/logs/compute;\
	vagrant destroy -f compute  # $@

# -----------------------------------------------------------------------------

clean: clean-cache clean-logs

clean-logs:
	rm -fR $(BUILD_DIR) $(LOG_DIR)  # $@

clean-cache: destroy
	rm -fR .vagrant */.tox  # $@

# -----------------------------------------------------------------------------

jenkins: $(BUILD_DIR)
	set -xe;\
	$(MAKE) update-box update-submodules destroy;\
	$(MAKE) apply-patchset;\
	$(MAKE) -j 2 tox stack-control  # $@

update-box: $(BUILD_DIR)
	if vagrant box outdated 2>&1 | grep 'vagrant box update'; then\
		$(MAKE) destroy;\
		vagrant box update;\
	fi  # $@

update-submodules: $(BUILD_DIR)
	set -xe;\
	$(GIT) submodule sync;\
	$(GIT) submodule update --init --remote --recursive;\
	$(GIT) submodule foreach '\
		set -ex;\
		INTEGRATION_BRANCH=$(MODULE_INTEGRATION_BRANCH);\
		$(GIT) rebase --abort || true;\
		$(GIT) cherry-pick --abort || true;\
		$(GIT) fetch origin $$INTEGRATION_BRANCH;\
		$(GIT) checkout -f FETCH_HEAD;\
		$(GIT) checkout -B integration/base;\
		if $(GIT) remote | grep gerrit > /dev/null; then\
			$(GIT) remote remove gerrit;\
		fi;\
		$(GIT) remote add -f gerrit $(MODULE_GERRIT_URL);\
		$(GIT) rebase gerrit/$(MODULE_GERRIT_BASE)'  # $@

apply-patchset:
	set -ex;\
	if [ -n "$(GERRIT_CHANGE_NUMBER)" ]; then\
		$(GIT) submodule foreach '\
			set -ex;\
			MODULE_GERRIT_PROJECT="$(MODULE_GERRIT_PROJECT)";\
			if [ "$${MODULE_GERRIT_PROJECT%.*}" == "$(GERRIT_PROJECT)" ]; then\
				$(GIT) review -vd $(GERRIT_CHANGE_NUMBER),$(GERRIT_PATCHSET_NUMBER);\
				$(GIT) rebase integration/base;\
			fi';\
	fi;\
	$(GIT) submodule foreach '\
		MODULE_GERRIT_PROJECT="$(MODULE_GERRIT_PROJECT)";\
		echo;\
		echo;\
		echo ["$$MODULE_GERRIT_PROJECT"];\
		$(GIT) log --graph -n 5;\
		echo;\
		echo';  # $@
