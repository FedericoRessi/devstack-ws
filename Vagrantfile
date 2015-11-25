# -*- mode: ruby -*-
# vi: set ft=ruby :

# --- VMs configuration -------------------------------------------------------

# number of CPUs for every VM
vm_cpus = 1

# megabytes of RAM for every VM
vm_memory = 4096

# available VM images
vm_images = [
  ["precise", "ubuntu/precise64"],
  ["trusty", "ubuntu/trusty64"],
  ["vivid", "ubuntu/vivid64"],
  ["wily", "ubuntu/wily64"],
  ["fedora21", "box-cutter/fedora21"],
  ["fedora22", "box-cutter/fedora22"],
  ["fedora23", "box-cutter/fedora23"],
  ["centos7", "puppetlabs/centos-7.0-64-nocm"]]

git_proxy_wrapper = ENV["GIT_PROXY_COMMAND"]

http_proxy = ENV["http_proxy"]
https_proxy = ENV["https_proxy"]
no_proxy = ENV["no_proxy"]

# --- vagrant meat ------------------------------------------------------------

Vagrant.configure(2) do |config|

  # For every available VM image
  vm_images.each do |vm_name, vm_image|
    config.vm.define vm_name do |conf|
      conf.vm.box = vm_image
      # conf.vm.hostname = vm_name

      conf.vm.network "private_network", type: "dhcp",
          virtualbox__intnet: "intnet1", auto_config: false
      conf.vm.network "private_network", type: "dhcp",
          virtualbox__intnet: "intnet2", auto_config: false

      # assign a different random port to every vm instance
      # this avoid concurrency problems when running tests in parallel
      conf.vm.network :forwarded_port, guest: 22, host: 22000 + rand(9999),
        id: "ssh", auto_correct: true
      conf.vm.network :forwarded_port, guest: 8080, host: 8080,
        id: "odl", auto_correct: true
      conf.vm.network :forwarded_port, guest: 80, host: 8000,
        id: "openstack", auto_correct: true
    end
  end

  config.vm.provider "virtualbox" do |vb|
      # Display the VirtualBox GUI when booting the machine
      vb.gui = false

      vb.memory = vm_memory  # VM ram
      vb.cpus = vm_cpus      # VM CPU cores
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