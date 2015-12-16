LOG_DIR = logs
LOG_FILE = $(LOG_DIR)/$(1).log

all: control compute


clean:
	vagrant destroy -f
	rm -fR $(LOG_DIR) .vagrant

control: control-up

compute: compute-up test-connectivity

control-up compute-up: $(LOG_DIR)


control compute: $(LOG_DIR)
	vagrant reload $@ > $(call LOG_FILE,03-$@-reboot)
	vagrant ssh $@ -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,04-$@-stack)


control-up:
	vagrant up control > $(call LOG_FILE,01-control-up)


compute-up:
	vagrant up compute > $(call LOG_FILE,01-compute-up)


test-connectivity: control-up compute-up
	vagrant ssh compute -c 'ping -c 1 control'
	vagrant ssh control -c 'ping -c 1 compute'


$(LOG_DIR):
	mkdir -p "$@"
