# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'


def get_global_conf()
	if File.file?('conf.yaml')
		return YAML.load_file('conf.yaml')
	else
		return {}

def get_guest_conf(global_conf, guest_class)
	conf_file_name = "#{guest_class}.conf.yaml"
	if File.file?(conf_file_name)
  		return global_conf.merge(YAML.load_file(conf_file_name)
  	else
  		return global_conf
	end

def get_string_option(guest_class, guest_conf, option_name)
	value = ENV[option_name"]
	if value == nil
		



def get_guest_cpus(conf, quest_name)
host_cpus = `python -c "import multiprocessing; print multiprocessing.cpu_count()"`.to_i
guest_cpus = ENV['GUEST_CPUS'].to_i
if guest_cpus < 1
	guest_cpus = conf["guest_cpus"].to_i
	if guest_cpus < 1
		guest_cpus = host_cpus / 2
	end
end

guest_cpus = [1, [guest_cpus, host_cpus, 32].min].max
print "guest_cpus: ", guest_cpus, "\n"

# --- vagrant box -------------------------------------------------------------

vagrant_boxes = {
    "ubuntu"   => "ubuntu/trusty64",
    "centos"  => "centos/7",
    "fedora" => "box-cutter/fedora22"}

vagrant_box_name = ENV["VAGRANT_BOX_NAME"]
if vagrant_box_name == nil
	vagrant_box_name = conf["vagrant_box_name"]
	if vagrant_box_name == nil
		vagrant_box_name = "ubuntu"
	end
end

vagrant_box = ENV["VAGRANT_BOX"]
if vagrant_box == nil
	vagrant_box = conf["vagrant_box"]
	if vagrant_box == nil
		vagrant_box = vagrant_boxes[vagrant_box_name]
	end
end

print "vagrant_box: ", vagrant_box, "\n"

# --- vagrant nodes -------------------------------------------------------------

# available VM images
vm_images = [
    ["control",
     '192.168.99.11',
     '192.168.50.11',
     8192],
    
    ["compute",
     '192.168.99.12',
     '192.168.50.12',
     4096],
]

git_proxy_wrapper = ENV["GIT_PROXY_COMMAND"]
http_proxy = ENV["http_proxy"]
https_proxy = ENV["https_proxy"]
no_proxy = ENV["no_proxy"]

# --- vagrant meat ------------------------------------------------------------

Vagrant.configure(2) do |config|

    # For every available VM image
    vm_images.each do |vm_name, vm_ip1, vm_ip2, vm_memory|
        config.vm.define vm_name do |conf|
            conf.vm.box = vagrant_box
            conf.vm.hostname = vm_name
            # control network
            conf.vm.network "private_network", ip: vm_ip1,
                virtualbox__intnet: "intnet1", auto_config: true
            # tenent network
            conf.vm.network "private_network", ip: vm_ip2,
                virtualbox__intnet: "intnet2", auto_config: true
            conf.vm.network "private_network", type: "dhcp",
                virtualbox__intnet: "intnet3", auto_config: false

            # assign a different random port to every vm instance
            # this avoid concurrency problems when running tests in parallel
            conf.vm.network :forwarded_port, guest: 22, host: 22000 + rand(9999),
                id: "ssh", auto_correct: true
            
            if vm_name == 'control'
                conf.vm.network :forwarded_port, guest: 6080, host: 6080,
                    id: "vnc-console", auto_correct: true
                conf.vm.network :forwarded_port, guest: 80, host: 8000,
                    id: "openstack", auto_correct: true

            end
           
            conf.vm.provider "virtualbox" do |vb|
               # Display the VirtualBox GUI when booting the machine
               vb.gui = false
               vb.memory = vm_memory  # VM ram
               vb.cpus = guest_cpus      # VM CPU cores
            end
        end
    end

    if Vagrant.has_plugin?("vagrant-proxyconf")
        if http_proxy != nil
            config.proxy.http = http_proxy
        end
        if https_proxy != nil
            config.proxy.https = https_proxy
        end
        if no_proxy != nil
            config.proxy.no_proxy = no_proxy
        end
    end

    if git_proxy_wrapper != nil
        config.vm.provision "file",
            source: git_proxy_wrapper,
            destination: "/home/vagrant/git_proxy_wrapper"
    end

    config.vm.provision "shell", inline: <<-SHELL
        su -l vagrant /vagrant/scripts/provision.sh
    SHELL
end
