#!/bin/bash

# Script to install the NodeSource Node.js 12.x repo onto a
# Debian or Ubuntu system.
#
# Run as root or insert `sudo -E` before `bash`:
#
# curl -sL https://deb.nodesource.com/setup_12.x | bash -
#   or
# wget -qO- https://deb.nodesource.com/setup_12.x | bash -
#

export DEBIAN_FRONTEND=noninteractive
SCRSUFFIX="_12.x"
NODENAME="Node.js 12.x"
NODEREPO="node_12.x"
NODEPKG="nodejs"

print_status() {
    echo
    echo "## $1"
    echo
}

if test -t 1; then # if terminal
    ncolors=$(which tput > /dev/null && tput colors) # supports color
    if test -n "$ncolors" && test $ncolors -ge 8; then
        termcols=$(tput cols)
        bold="$(tput bold)"
        underline="$(tput smul)"
        standout="$(tput smso)"
        normal="$(tput sgr0)"
        black="$(tput setaf 0)"
        red="$(tput setaf 1)"
        green="$(tput setaf 2)"
        yellow="$(tput setaf 3)"
        blue="$(tput setaf 4)"
        magenta="$(tput setaf 5)"
        cyan="$(tput setaf 6)"
        white="$(tput setaf 7)"
    fi
fi

print_bold() {
    title="$1"
    text="$2"

    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
    echo
    echo -e "  ${bold}${yellow}${title}${normal}"
    echo
    echo -en "  ${text}"
    echo
    echo "${red}================================================================================${normal}"
    echo "${red}================================================================================${normal}"
}

bail() {
    echo 'Error executing command, exiting'
    exit 1
}

exec_cmd_nobail() {
    echo "+ $1"
    bash -c "$1"
}

exec_cmd() {
    exec_cmd_nobail "$1" || bail
}

setup() {

print_status "Installing the NodeSource ${NODENAME} repo..."

if $(uname -m | grep -Eq ^armv6); then
    print_status "You appear to be running on ARMv6 hardware. Unfortunately this is not currently supported by the NodeSource Linux distributions. Please use the 'linux-armv6l' binary tarballs available directly from nodejs.org for Node.js 4 and later."
    exit 1
fi

PRE_INSTALL_PKGS=""

# Check that HTTPS transport is available to APT
# (Check snaked from: https://get.docker.io/ubuntu/)

if [ ! -e /usr/lib/apt/methods/https ]; then
    PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} apt-transport-https"
fi

if [ ! -x /usr/bin/lsb_release ]; then
    PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} lsb-release"
fi

if [ ! -x /usr/bin/curl ] && [ ! -x /usr/bin/wget ]; then
    PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} curl"
fi

# Used by apt-key to add new keys

if [ ! -x /usr/bin/gpg ]; then
    PRE_INSTALL_PKGS="${PRE_INSTALL_PKGS} gnupg"
fi

# Populating Cache
print_status "Populating apt-get cache..."
exec_cmd 'apt-get update'

if [ "X${PRE_INSTALL_PKGS}" != "X" ]; then
    print_status "Installing packages required for setup:${PRE_INSTALL_PKGS}..."
    # This next command needs to be redirected to /dev/null or the script will bork
    # in some environments
    exec_cmd "apt-get install -y${PRE_INSTALL_PKGS} > /dev/null 2>&1"
fi

IS_PRERELEASE=$(lsb_release -d | grep 'Ubuntu .*development' >& /dev/null; echo $?)
if [[ $IS_PRERELEASE -eq 0 ]]; then
    print_status "Your distribution, identified as \"$(lsb_release -d -s)\", is a pre-release version of Ubuntu. NodeSource does not maintain official support for Ubuntu versions until they are formally released. You can try using the manual installation instructions available at https://github.com/nodesource/distributions and use the latest supported Ubuntu version name as the distribution identifier, although this is not guaranteed to work."
    exit 1
fi

DISTRO=$(lsb_release -c -s)

if [ "X${DISTRO}" == "Xnoble" ]; then
  print_status "Adjusting distribution name for Ubuntu 24.04..."
  DISTRO="jammy"
fi

print_status "Confirming \"${DISTRO}\" is supported..."

if [ -x /usr/bin/curl ]; then
    exec_cmd_nobail "curl -sLf -o /dev/null 'https://deb.nodesource.com/${NODEREPO}/dists/${DISTRO}/Release'"
    RC=$?
else
    exec_cmd_nobail "wget -qO /dev/null -o /dev/null 'https://deb.nodesource.com/${NODEREPO}/dists/${DISTRO}/Release'"
    RC=$?
fi

if [[ $RC != 0 ]]; then
    print_status "Your distribution, identified as \"${DISTRO}\", is not currently supported, please contact NodeSource at https://github.com/nodesource/distributions/issues if you think this is incorrect or would like your distribution to be considered for support"
    exit 1
fi

if [ -f "/etc/apt/sources.list.d/chris-lea-node_js-$DISTRO.list" ]; then
    print_status 'Removing Launchpad PPA Repository for NodeJS...'

    exec_cmd_nobail 'add-apt-repository -y -r ppa:chris-lea/node.js'
    exec_cmd "rm -f /etc/apt/sources.list.d/chris-lea-node_js-${DISTRO}.list"
fi

print_status 'Adding the NodeSource signing key to your keyring...'
keyring='/usr/share/keyrings'
node_key_url="https://deb.nodesource.com/gpgkey/nodesource.gpg.key"
local_node_key="$keyring/nodesource.gpg"

if [ -x /usr/bin/curl ]; then
    exec_cmd "curl -s $node_key_url | gpg --dearmor | tee $local_node_key >/dev/null"
else
    exec_cmd "wget -q -O - $node_key_url | gpg --dearmor | tee $local_node_key >/dev/null"
fi

print_status "Creating apt sources list file for the NodeSource ${NODENAME} repo..."

exec_cmd "echo 'deb [signed-by=$local_node_key] https://deb.nodesource.com/${NODEREPO} ${DISTRO} main' > /etc/apt/sources.list.d/nodesource.list"
exec_cmd "echo 'deb-src [signed-by=$local_node_key] https://deb.nodesource.com/${NODEREPO} ${DISTRO} main' >> /etc/apt/sources.list.d/nodesource.list"

print_status 'Running `apt-get update` for you...'

exec_cmd 'apt-get update'

yarn_site='https://dl.yarnpkg.com/debian'
yarn_key_url="$yarn_site/pubkey.gpg"
local_yarn_key="$keyring/yarnkey.gpg"

print_status """Run \`${bold}sudo apt-get install -y ${NODEPKG}${normal}\` to install ${NODENAME} and npm
## You may also need development tools to build native addons:
     sudo apt-get install gcc g++ make
## To install the Yarn package manager, run:
     curl -sL $yarn_key_url | gpg --dearmor | sudo tee $local_yarn_key >/dev/null
     echo \"deb [signed-by=$local_yarn_key] $yarn_site stable main\" | sudo tee /etc/apt/sources.list.d/yarn.list
     sudo apt-get update && sudo apt-get install yarn
"""

}

## Defer setup until we have the complete script
setup
