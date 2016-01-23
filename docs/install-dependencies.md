# Install project dependencies

This project is being used and tested on following operative systems:
  * Ubuntu Linux [14.04 LTS](http://releases.ubuntu.com/14.04/) (Trusty Tahr)
  * [OSX](http://www.apple.com/osx/) 10.11.3 (El Capitan)
  * [Fedora](https://getfedora.org) 21
  
To use it you need to install following project dependencies:
 * [Command line tools](GNU Make, Git, wget, ...)
 * [Python](https://www.python.org) 2.7
 * [Virtual Box](https://www.virtualbox.org) 5.0
 * [Vagrant](https://www.vagrantup.com/downloads.html) 1.8

## Install command line tools (Git, GNU Make, etc.)

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
A dialog box with an `Install` button should appear to you:
```
TODO: put dialog image here.
```
Click Install and follow installation process. It should some minutes to download and install command line development tools.

If it doesn't work for you please look in the web how to [install command line developer tools in os x](http://www.cnet.com/uk/how-to/install-command-line-developer-tools-in-os-x/)


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

