LOG_DIR = logs
LOG_FILE = $(LOG_DIR)/$(1).log

all: networking-odl control compute


clean:
	vagrant destroy -f
	rm -fR $(LOG_DIR) .vagrant .tox

control: control-up

compute: control compute-up

control-up compute-up: $(LOG_DIR)


control: $(LOG_DIR)
	vagrant ssh control -c "cd /opt/stack/devstack && ./unstack.sh" || true > $(call LOG_FILE,04-control-unstack) 2>&1
	vagrant ssh control -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,04-control-stack) 2>&1

compute: $(LOG_DIR)
	# test connectivity with control node
	vagrant ssh compute -c 'wget control:5000 -o /dev/null'
	vagrant ssh compute -c "cd /opt/stack/devstack && ./unstack.sh" || true > $(call LOG_FILE,04-compute-unstack) 2>&1
	# make sure it uses last kernel
	vagrant reload control > $(call LOG_FILE,02-control-reboot) 2>&1
	vagrant ssh compute -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,04-compute-stack) 2>&1

control-up:
	vagrant up control > $(call LOG_FILE,01-control-up) 2>&1

networking-odl: control-up
	if [ -d $@ ]; then vagrant ssh control -c 'cd /vagrant/$@ && tox -v' > $(call LOG_FILE,03-control-$@) 2>&1; fi

compute-up:
	vagrant up compute > $(call LOG_FILE,01-compute-up) 2>&1


$(LOG_DIR):
	mkdir -p "$@"
