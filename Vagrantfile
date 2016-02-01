# -*- mode: ruby -*-
# vi: set ft=ruby :

# --- VMs configuration -------------------------------------------------------

# number of CPUs for every VM
host_cpus = `python -c "import multiprocessing; print multiprocessing.cpu_count()"`.to_i
max_cpus = [host_cpus, 32].min
min_cpus = 1

vm_cpus = ENV['VAGRANT_CPUS'].to_i
if vm_cpus == 0
    vm_cpus = host_cpus / 2
end
vm_cpus = [min_cpus, vm_cpus, max_cpus].sort[1]

vm_boxes = {
    "precise"  => "ubuntu/precise64",
    "trusty"   => "ubuntu/trusty64",
    "vivid"    => "ubuntu/vivid64",
    "wily"     => "ubuntu/wily64",
    "fedora21" => "box-cutter/fedora21",
    "fedora22" => "box-cutter/fedora22",
    "fedora23" => "box-cutter/fedora23",
    "centos7"  => "puppetlabs/centos-7.2-64-nocm"}

use_nfs = false
if ENV["USE_NFS"] == "true"
    use_nfs = true
end
nfs_mount_options = ['rw', "vers=3", 'tcp', 'fsc']

vm_box_name = ENV["VAGRANT_BOX_NAME"]
if vm_box_name == nil
    vm_box_name = "trusty"
elsif vm_box_name == "centos7"
    vm_cpus = 1
    use_nfs = true
end

# available VM images
vm_images = [
    ["control",
     vm_box_name,
     '192.168.1.10',
     '192.168.2.10',
     '192.168.3.10',
     12288],

    ["compute",
     vm_box_name,
     '192.168.1.11',
     '192.168.2.11',
     '192.168.3.11',
     16384],
]

git_proxy_wrapper = ENV["GIT_PROXY_COMMAND"]
http_proxy = ENV["http_proxy"]
https_proxy = ENV["https_proxy"]
no_proxy = ENV["no_proxy"]

build_dir = ENV["BUILD_DIR"]
if build_dir == nil
    build_dir = "#{Dir.pwd}/build/0"
end

log_dir = ENV["LOG_DIR"]
if log_dir == nil
    log_dir = "#{build_dir}/logs"
end

stack_dir = ENV["STACK_DIR"]
if stack_dir == nil
    stack_dir = "#{build_dir}/stack"
end

user_id = ENV["USER"]
if user_id == nil
    user_id = "anonymous"
fi

# --- vagrant meat ------------------------------------------------------------

Vagrant.configure(2) do |config|

    # For every available VM image
    vm_images.each do |vm_name, vm_image, control_ip, tenent_ip, nfs_ip, vm_memory|
        config.vm.define vm_name do |conf|
            conf.vm.box = vm_boxes[vm_image]
            conf.vm.hostname = vm_name
            # control network
            conf.vm.network "private_network", ip: control_ip,
                virtualbox__intnet: "controlnet-#{log_dir}", auto_config: true
            # tenent network
            conf.vm.network "private_network", ip: tenent_ip,
                virtualbox__intnet: "tenentnet-#{log_dir}", auto_config: true

            # assign a different random port to every vm instance
            # this avoid concurrency problems when running tests in parallel
            conf.vm.network :forwarded_port, guest: 22,
                host: 22000 + rand(9999), id: "ssh", auto_correct: true

            if vm_name == 'control'
                conf.vm.network :forwarded_port, guest: 6080, host: 6080,
                    id: "vnc-console", auto_correct: true
                conf.vm.network :forwarded_port, guest: 80, host: 8000,
                    id: "openstack", auto_correct: true
            end

            if use_nfs
                # nfs network
                conf.vm.network "private_network", ip: nfs_ip, auto_config: true
                conf.nfs.map_uid = Process.uid
                conf.vm.synced_folder ".", "/vagrant", create: true,
                    type: "nfs", mount_options: nfs_mount_options
                conf.vm.synced_folder "#{log_dir}/#{vm_name}",
                    "/opt/stack/logs", create: true,
                    type: "nfs", mount_options: nfs_mount_options
            else
                conf.vm.synced_folder "#{log_dir}/#{vm_name}",
                    "/opt/stack/logs", create: true
            end

            conf.vm.provider "virtualbox" do |vb|
                # Display the VirtualBox GUI when booting the machine
                vb.gui = false
                vb.memory = vm_memory  # VM ram
                vb.cpus = vm_cpus      # VM CPU cores
                # openstack guests to talk to each other
                vb.customize ["modifyvm", :id, "--nicpromisc2", "allow-all"]
            end
        end
    end

    # try fixing NAT crashes
    config.vm.provider :virtualbox do |vb|
        vb.customize ['modifyvm', :id, '--natdnshostresolver1', 'on']
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

    if Vagrant.has_plugin?("vagrant-cachier")
        config.cache.scope = :machine
        if use_nfs
            config.cache.synced_folder_opts = {
                type: :nfs,
                mount_options: nfs_mount_options
            }
        end
    end

    if Vagrant.has_plugin?("vagrant-vbguest")
        config.vbguest.auto_update = false
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
