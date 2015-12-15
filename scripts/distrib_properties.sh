
function read_variable {
    (
        local FILE_NAME="$1"
        local VARIABLE_NAME="$2"
        source $FILE_NAME
        eval "echo \$$VARIABLE_NAME"
    )
}


if [ -r  /etc/lsb-release ]; then
    # Ubuntu way
    DISTRIB_ID="$(read_variable /etc/lsb-release DISTRIB_ID)"
    DISTRIB_RELEASE="$(read_variable /etc/lsb-release DISTRIB_RELEASE)"
    DISTRIB_CODENAME="$(read_variable /etc/lsb-release DISTRIB_CODENAME)"
    DISTRIB_DESCRIPTION="$(read_variable /etc/lsb-release DISTRIB_DESCRIPTION)"

elif [ -r /etc/os-release ]; then
    # Redhat way
    DISTRIB_ID="$(read_variable /etc/os-release ID)"
    DISTRIB_RELEASE="$(read_variable /etc/os-release VERSION_ID)"
    DISTRIB_CODENAME="$(read_variable /etc/os-release ID)$DISTRIB_RELEASE"
    DISTRIB_DESCRIPTION="$(read_variable /etc/os-release PRETTY_NAME)"

else
    DISTRIB_ID="Unknown"
    DISTRIB_RELEASE="Unknown"
    DISTRIB_CODENAME="unknown"
    DISTRIB_DESCRIPTION="Unknown Linux Distribution"

fi

export DISTRIB_ID DISTRIB_RELEASE DISTRIB_CODENAME DISTRIB_DESCRIPTION

if which apt-get 2> /dev/null; then
    PACKAGER="apt-get"

elif which dnf 2> /dev/null; then
    PACKAGER="dnf"

elif which yum 2> /dev/null; then
    PACKAGER="yum"

else
    echo "Unsupported distribution."
    cat /etc/*-release
    exit 1
fi

export PACKAGER


function is_ubuntu {
    [[ "$DISTRIB_ID" == "Ubuntu" ]]
}

function is_fedora {
    [[ "$DISTRIB_ID" == "fedora" ]]
}

function is_centos {
    [[ "$DISTRIB_ID" == "centos" ]]
}

function install_package {
    sudo $PACKAGER install -y "$@"
}
