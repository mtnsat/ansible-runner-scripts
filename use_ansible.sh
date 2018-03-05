#!/usr/bin/env bash

#-------------------------------------
# use_ansible.sh
#
# Script to install and run ansible 2.x from virtualenv
# or from github source checked out in /tmp
#
# ( This only works from within a script.
#   if you source it from the command prompt,
#   nothing will happen. )
#
# Authors: Shaun Smiley
#          Rowin Andruscavage
#
# VENV vars
#   USE_ANSIBLE_MODE=virtualenv ## default
#   USE_ANSIBLE_VENV_VER=2.4 # example value
#
# GIT vars
#   USE_ANSIBLE_MODE=git
#   USE_ANSIBLE_VER='v2.4.0.0-1' # example value
#
#-------------------------------------

#-------------------------------------
##- vars
#-------------------------------------
## virtualenv or git
run_mode="${USE_ANSIBLE_MODE:-virtualenv}"

## virtualenv configuration
[[ -n $USE_ANSIBLE_VENV_DIR && -n $USE_ANSIBLE_VENV_REQ ]] && {
  VENV="${USE_ANSIBLE_VENV_DIR:-venv-ansible2.0}"
  REQUIREMENTS="${USE_ANSIBLE_VENV_REQ:-requirements-ansible2.0.txt}"
} || {
  [[ -n $USE_ANSIBLE_VENV_VER ]] || {
    USE_ANSIBLE_VENV_VER='2.4' #default
  }

  case $USE_ANSIBLE_VENV_VER in
    2.0)
      VENV='venv-ansible2.0'
      REQUIREMENTS='requirements-ansible2.0.txt'
      ;;
    2.2)
      VENV='venv-ansible2.2'
      REQUIREMENTS='requirements-ansible2.2.txt'
      ;;
    2.3)
      VENV='venv-ansible2.3'
      REQUIREMENTS='requirements-ansible2.3.txt'
      ;;
    2.4)
      VENV='venv-ansible2.4'
      REQUIREMENTS='requirements-ansible2.4.txt'
      ;;
    *)
      echo 'unrecognized USE_ANSIBLE_VENV_VER'
      echo 'use "2.0", "2.2", "2,3" or "2.4"'
      exit 1
      ;;
  esac
}

## git checkout dir
co='/usr/local/bin/ansible-git'
co_run="${co}/hacking/env-setup"

## debug mode
debug_mode="${USE_ANSIBLE_DEBUG:-false}"
[[ $debug_mode == 'true' ]] && { echo "run_mode: ${run_mode}"; echo; }

## git checkout tag
# ansible_ver="${USE_ANSIBLE_VER:-v2.0.2.0-1}"
# ansible_ver="${USE_ANSIBLE_VER:-v2.1.6.0-1}"
# ansible_ver="${USE_ANSIBLE_VER:-v2.2.3.0-1}"
ansible_ver="${USE_ANSIBLE_VER:-v2.3.2.0-1}" # default for git method
# ansible_ver="${USE_ANSIBLE_VER:-v2.4.0.0-1}"
# ansible_ver="${USE_ANSIBLE_VER:-v2.4.1.0-0.4.rc2}"




#-------------------------------------
##- virtualenv functions
#-------------------------------------

which pacman && {
  VENV_BIN='virtualenv2'
  PIP_BIN='pip2'
} || {
  VENV_BIN='virtualenv'
  PIP_BIN='pip'
}


virtualenv_setup() {
  ## One-time OS setup for virtualenv

  ## Ubuntu virtualenv install
  [[ $(which apt-get 2>/dev/null) ]] && {
    [[ $(which virtualenv) ]] || {
      echo "*** virtualenv not installed."
      echo "*** Attempting installation..."
      sudo apt-get install -y python-virtualenv
    }
    for PKG in python-dev libffi-dev libssl-dev build-essential ; do
      [[ $(dpkg -s $PKG) ]] || {
        sudo apt-get install -y -f $PKG
      }
    done
  }

  ## Mac OS X virtualenv install
  [[ $(uname) == 'Darwin' ]] && {
    [[ $(which virtualenv) ]] || {
      echo "Error. Python virtualenv not present. Please install."
      echo "  NB: usually pip install virtualenv will work."
      exit 1
    }
  }

  ## Arch Linux
  which pacman 2>/dev/null && {
    for PKG in base-devel python2 python2-virtualenv python2-pip; do
      pacman -Qqe | grep "$PKG" || {
        pacman -Sy --needed --noconfirm "$PKG"
      }
    done
  }


}

run_from_virtualenv() {
  if [[ ! -f $REQUIREMENTS ]]; then
    echo "Requirements file ${REQUIREMENTS} missing."
    echo "Exiting."
    exit 1
  fi
  [[ -d $VENV ]] || {
    virtualenv_setup
    echo "*** activating virtualenv: ${VENV}"
    $VENV_BIN $VENV
    source ./$VENV/bin/activate
    $PIP_BIN install -U setuptools
    $PIP_BIN install -U pip
    $PIP_BIN install -r $REQUIREMENTS
    deactivate
  }

  echo "Sourcing ansible venv."
  source ./$VENV/bin/activate
  echo "Ensuring python requirements."
  [[ $debug_mode == 'true' ]] && {
    $PIP_BIN install -r $REQUIREMENTS
  } || {
    $PIP_BIN install -r $REQUIREMENTS >/dev/null
  }

  echo; ansible --version; echo
  export PYTHONPATH="venv-ansible${USE_ANSIBLE_VENV_VER}/lib/python2.7/site-packages/"
}




#-------------------------------------
##- git functions
#-------------------------------------
co_version() {
  ## checkout desired version of ansible from git
  cd "${co}" >/dev/null 2>&1

  local current_version=$(git describe --tags)
  [[ "$current_version" == "$ansible_ver" ]] && {
    echo "Already on ansible $ansible_ver."
  } || {
    echo "Updating ansible git..."
    git checkout devel >/dev/null 2>&1
    git pull --rebase >/dev/null 2>&1
    git checkout "${ansible_ver}" >/dev/null 2>&1
    git submodule update --init --recursive >/dev/null 2>&1
    #verify what tag we're on now
    echo "Now on Ansible $(git describe --tags)"
  }

}

source_ansible() {
  ## source ansible version into current shell
  source "${co_run}" >/dev/null 2>&1
}

run_from_git() {
  [[ $(which git) ]] || {
      echo "Git not installed.  Aborting..."
      exit 1
  }

  [[ -f "${co_run}" ]] || {
      echo "Ansible git repo not yet checked out at ${co}."
      sudo mkdir "${co}"
      sudo chown $(whoami) "${co}"
      git clone https://github.com/ansible/ansible.git "${co}"
  }

  ## save current directory
  pushd .  >/dev/null 2>&1

  co_version
  source_ansible

  ## return to original directory
  popd  >/dev/null 2>&1

  echo; ansible --version; echo
}




#-------------------------------------
##- main
#-------------------------------------
[[ $run_mode == 'virtualenv' ]] && run_from_virtualenv
[[ $run_mode == 'git' ]] && run_from_git
