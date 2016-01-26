# Global variables ------------------------------------------------------------

BUILD_NUMBER ?= 0
export BUILD_DIR ?= $(abspath build/$(BUILD_NUMBER))
export LOG_DIR := $(BUILD_DIR)/logs
# export STACK_DIR := $(BUILD_DIR)/stack

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

# Valid values: guest, host, skip
TOX_MODE ?= host


all: tox stack-control


WORK_DIRS = $(BUILD_DIR) $(LOG_DIR) # $(STACK_DIR)


$(LOG_DIR):
	mkdir -p $(LOG_DIR);\
	ln -sfn $(LOG_DIR) ./logs


# $(STACK_DIR):
# 	mkdir -p $(STACK_DIR);\
# 	ln -sfn $(STACK_DIR) ./stack


$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)


# -----------------------------------------------------------------------------
# TOX support

tox: tox-devstack tox-networking-odl

# if TOX_MODE is host then run tox inside of host machine
ifeq ($(TOX_MODE),host)
    RUN_TOX = cd $1; $(TOX)
endif

# if TOX_MODE is guest then run tox inside of control VM after it is stacked
ifeq ($(TOX_MODE),guest)
    tox-devstack tox-networking-odl: create-control
    RUN_TOX = vagrant ssh control -c 'cd /opt/stack/$1; $(TOX)'
endif

# if TOX_MODE is skip then skip running tox at all
ifeq ($(TOX_MODE),skip)
    RUN_TOX = echo "Skip running tox."
endif

ifeq ($(RUN_TOX),)
    $(error TOX_MODE can be only: host, guest or skip)
endif


tox-devstack: $(WORK_DIRS)
	unset PYTHONPATH;\
	set -e;\
	$(call RUN_TOX,devstack) # $@

tox-networking-odl: $(WORK_DIRS)
	unset PYTHONPATH;\
	set -e;\
	$(call RUN_TOX,networking-odl) # $@


# -----------------------------------------------------------------------------

create: create-control create-compute

create-control: $(WORK_DIRS)
	if ! vagrant ssh control -c '[ -f ~/CREATED ]'; then\
    	set -xe;\
    	vagrant up control --no-provision;\
    	vagrant provision control;\
    	vagrant reload control;\
    	vagrant ssh control -c 'touch ~/CREATED';\
	fi  # $@

create-compute: $(WORK_DIRS)
	if ! vagrant ssh compute -c '[ -f ~/CREATED ]'; then\
    	set -xe;\
    	vagrant up compute --no-provision;\
    	vagrant provision compute;\
    	vagrant reload compute;\
    	vagrant ssh compute -c 'touch ~/CREATED;'\
	fi  # $@

# -----------------------------------------------------------------------------

stack: stack-control stack-compute

stack-control: create-control
	set -xe;\
	vagrant ssh control -c '\
		if ! [ -f ~/STACKED ]; then\
    		set -xe;\
    		(cd /opt/stack/devstack && GIT_BASE=$$GIT_BASE ./stack.sh);\
    		touch ~/STACKED;\
		fi'  # $@

stack-compute: create-compute
	set -xe;\
	vagrant ssh compute -c '\
		if ! [ -f ~/STACKED ]; then\
    		set -xe;\
    		(cd /opt/stack/devstack && GIT_BASE=$$GIT_BASE ./stack.sh);\
    		touch ~/STACKED;\
		fi'  # $@

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
	rm -fR $(LOG_DIR)  # $@

clean-cache: destroy
	rm -fR .vagrant */.tox $(WORK_DIRS) # $@

# -----------------------------------------------------------------------------

jenkins: $(WORK_DIRS)
	set -xe;\
	$(MAKE) destroy update-box update-submodules;\
	$(MAKE) apply-patchset;\
	$(MAKE) tox stack-control  # $@

update-box: $(WORK_DIRS)
	if vagrant box outdated 2>&1 | grep 'vagrant box update'; then\
		$(MAKE) destroy;\
		vagrant box update || true;\
	fi  # $@

update-submodules: $(WORK_DIRS)
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
