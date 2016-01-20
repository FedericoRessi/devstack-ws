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

TOX ?= tox
TOX_IN_VM ?= false


all: tox stack


# -----------------------------------------------------------------------------

tox: tox-devstack tox-networking-odl

# if TOX_IN_VM is true then run tox inside of control VM after it is stacked
ifeq ($(TOX_IN_VM),true)
    RUN_TOX = vagrant ssh -c 'cd /opt/stack/$1; $(TOX)'
    tox-devstack tox-networking-odl: stack-control
else
    RUN_TOX = cd $1; $(TOX)
endif
ifneq ($(TOX_IN_VM),false)
    $(warning TOX_IN_VM can be only true or false)
endif


tox-devstack: $(LOG_DIR)
	unset PYTHONPATH;\
	set -e;\
	$(call RUN_TOX,devstack) # $@

tox-networking-odl: $(LOG_DIR)
	unset PYTHONPATH;\
	set -e;\
	$(call RUN_TOX,networking-odl) # $@


$(LOG_DIR):
	mkdir -p $(LOG_DIR);\
	ln -sfn $(LOG_DIR) ./logs

# -----------------------------------------------------------------------------

create: create-control create-compute

create-control: $(LOG_DIR)
	set -xe;\
	vagrant status | grep control | grep 'not created' || exit 0;\
	vagrant up control;\
	vagrant reload control  # $@

create-compute: $(LOG_DIR)
	set -xe;\
	vagrant status | grep compute | grep 'not created' || exit 0;\
	vagrant up compute;\
	vagrant reload compute  # $@

# -----------------------------------------------------------------------------

stack: stack-control stack-compute

stack-control: create-control
	set -xe;\
	vagrant up control;\
	vagrant ssh control -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		./stack.sh;\
		[ -f STACKED ] || (./stack.sh && touch STACKED);  # $@

stack-compute: create-compute
	set -xe;\
	vagrant up compute;\
	vagrant ssh compute -c '\
		set -xe;\
		cd /opt/stack/devstack;\
		[ -f STACKED ] || (./stack.sh && touch STACKED);  # $@

# -----------------------------------------------------------------------------

destroy: destroy-control destroy-compute

destroy-control:
	rm -fR $(LOG_DIR)/control;\
	vagrant destroy -f control  # $@

destroy-compute:
	rm -fR $(LOG_DIR)/compute;\
	vagrant destroy -f compute  # $@

# -----------------------------------------------------------------------------

clean: clean-cache clean-logs

clean-logs:
	rm -fR $(LOG_DIR) $(BUILD_DIR)  # $@

clean-cache: destroy
	rm -fR .vagrant */.tox  # $@

# -----------------------------------------------------------------------------

jenkins: $(LOG_DIR)
	set -xe;\
	$(MAKE) destroy update-box update-submodules;\
	$(MAKE) apply-patchset;\
	$(MAKE) tox stack-control  # $@

update-box: $(LOG_DIR)
	if vagrant box outdated 2>&1 | grep 'vagrant box update'; then\
		$(MAKE) destroy;\
		vagrant box update;\
	fi  # $@

update-submodules: $(LOG_DIR)
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
