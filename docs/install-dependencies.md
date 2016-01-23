# Install project dependencies

This project is being used and tested on following operative systems:
  * Ubuntu Linux [14.04 LTS](http://releases.ubuntu.com/14.04/) (Trusty Tahr)
  * [OSX](http://www.apple.com/osx/) 10.11.3 (El Capitan)
  * [Fedora](https://getfedora.org) 21
  
To use it you need to install following project dependencies:
 * [Command line tools](GNU Make, Git, wget, ...)
 * [Python](https://www.python.org) 2.7 with required libraries
 * [Vagrant](https://www.vagrantup.com/downloads.html) 1.8
 * [Virtual Box](https://www.virtualbox.org) 5.0

## Install command line tools (Git, GNU Make, etc.)

Most of Unix operative system should provide required command line tools.

### Install command line tools on OSX

Open the terminal and type required commands:
```
make --version
git --version
wget --version
```

If it is not installed you should expect an error message similar to this one:
```
xcode-select: note: no developer tools were found at '/Applications/Xcode.app', requesting install.
Choose an option in the dialog to download the command line developer tools.
```
A dialog box with an `Install` button should appear to you: click Install and follow installation process.
It should some minutes to download and install command line development tools.

If it doesn't work for you please look in the web how to [install command line developer tools in os x](http://www.cnet.com/uk/how-to/install-command-line-developer-tools-in-os-x/).


## Install Python dependencies

### Install pip
[Download pip installer](https://bootstrap.pypa.io/get-pip.py) and from the same folder where you save it type following:
```
sudo python get-pip.py
```
#### Downgrade pip
At this point you could have installed pip 8.0. In this moment DevStack is not supporting such version and if you want to run tox in the host machine instead of guest virtual machine provided by Vagrant then you should downgrade pip to the last version 7 and install tox as following:
```
sudo pip install -U 'pip<8' tox
```
You should expect producing similar lines in output telling you that installation and downgrade has been successeful:
```
Successfully installed pip-7.1.2
Successfully installed pluggy-0.3.1 py-1.4.31 tox-2.3.1 virtualenv-14.0.1
```
### Install required Python libraries
From terminal type:
```
sudo pip install ansi2html sh
```

## Install and configure Vagrant

 Download last Vagrant for your operative system from [here](https://www.vagrantup.com/downloads.html)
 Once installed you should install required plugins from terminal as following:
 ```
 vagrant plugin install vagrant-proxyconf
 vagrant plugin install vagrant-cachier
 ```
 Then type `vagrant plugin list` to look if above plugins are listed as following:
 * vagrant-cachier (1.2.1)
 * vagrant-proxyconf (1.5.2)

## Verify installation tu run DevStack

Creating a VM the first time requires to download a lot of files from internet. Most of this files will be cachied on `.vagrant` hidden folder to speedup next times the VM is created.
Clone the workspace and looks if it can creates a VM typing following
```
git clone https://github.com/FedericoRessi/devstack-ws.git
cd devstack-ws
make create-control
```

You should have any error and you should expect having logs folder with all logs files marked terminating with '_SUCCESS.html' and no one marked as '_FAILED.html'. For example typing `ls logs` you should expect:
```
2016-01-23_12:51:28_create-control_SUCCESS.ansi	2016-01-23_12:51:28_create-control_SUCCESS.txt
2016-01-23_12:51:28_create-control_SUCCESS.html
```

### About proxy configuration
proxy enviroment variables as `http_proxy`, `https_proxy` and `no_proxy` found in host machine should be automatically forwarded to guest machine when creating it. If a sock proxy is required to use `GIT_PROXY_COMMAND` for having access to external repositories then the enviroment varriable will be used to search for your git proxy script and it will be installed inside guests VMS in `/etc/default/` then the enviroment vagrable in the VM will be set properly to be exported by /etc/profile when logging in.

### Run OpenStack with DevStack
After editing control.local.conf file with the configuration you would like to run just type following:
```
make stack-control
```
