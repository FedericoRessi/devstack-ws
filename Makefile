LOG_DIR = logs
LOG_FILE = $(LOG_DIR)/$(1).log

all: control compute


clean:
	vagrant destroy -f
	rm -fR $(LOG_DIR) .vagrant

control compute: $(LOG_DIR)
	vagrant up --no-provision $@ > $(call LOG_FILE,01-$@-up)
	vagrant provision $@ > $(call LOG_FILE,02-$@-provision)
	vagrant reload $@  > $(call LOG_FILE,03-$@-reboot)
	vagrant ssh $@ -c "cd /opt/stack/devstack && ./stack.sh" > $(call LOG_FILE,04-$@-stack)

$(LOG_DIR):
	mkdir -p "$@"
	