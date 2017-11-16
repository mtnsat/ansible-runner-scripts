#!/usr/bin/env bash
#----------------------------------------------------
#
# base_run.sh - base script to be run by run_*
#
# ENV Vars:
#   VAGRANT_MODE - [0,1] 
#     - to be used with bovine-inventory's vagrant mode
#   ANSIBLE_BASE_RUN_MODE - ["playbook","ad-hoc"]
#     - specify which mode to run ansible in
#   ANSIBLE_PLAYBOOK - defaults to "site.yml"
#     - specify playbook to pass to ansible-playbook
#     - NB: only used when run mode is "playbook"
#   ANSIBLE_BASE_ARA - ["0","1"]
#     - a bash STRING (not numeral) to enable ARA
#   VAULT_PASSWORD_FILE - 
#
# CONFIGURATION:
#   Configuration can be overridden by defining vars
#   in the following script, which is not git tracked:
#     - cfg.base_run.sh
#   A sample is provided in
#     - cfg.base_run.sh.example
# 
#
# Example:
#   --- run_this.sh ---
#   #!/usr/bin/env bash
#
#   export ANSIBLE_BASE_RUN_MODE='playbook'
#   export ANSIBLE_PLAYBOOK='site.yml'
#
#   source base_run.sh

#   ./base_run.sh "${@}"
#
#----------------------------------------------------
#set -e

if [[ -f cfg.base_run.sh ]]; then
  source cfg.base_run.sh
fi

export ANSIBLE_FORCE_COLOR="${ANSIBLE_FORCE_COLOR:-true}"
export VAGRANT_MODE="${VAGRANT_MODE:-0}" #1=enabled, disabled by default

INOPTS=("$@")

if [ $# -eq 0 ]; then
  echo "No arguments provided, please provide at least one argument"
  echo "Example: ./run_this.sh -v"
  exit 1
fi

mode="${ANSIBLE_BASE_RUN_MODE:-playbook}"
echo "****** RUN MODE= ${ANSIBLE_BASE_RUN_MODE}"

if [[ ${ANSIBLE_BASE_RUN_MODE} == 'playbook' ]]; then
  playbook="${ANSIBLE_PLAYBOOK:-site.yml}"
  echo "****** PLAYBOOK= ${playbook}"
fi

echo "****** VAGRANT_MODE= ${VAGRANT_MODE}"


source use_ansible.sh

# Plaintext vault decryption key, not checked into SCM
if [[ -f $VAULT_PASSWORD_FILE ]]; then
  VAULTOPTS="--vault-password-file=$VAULT_PASSWORD_FILE"
else
  if [[ $ANSIBLE_BASE_RUN_MODE == "playbook" ]]; then
    # tag plays and role with "required_vault" to be able to skip vault required tasks
    VAULTOPTS="--skip-tags requires_vault"
  else
    # there is no --skip-tags for ad-hoc mode
    VAULTOPTS=""
  fi
fi

setup_ara() {
  export ara_location=$(python -c "import os,ara; print(os.path.dirname(ara.__file__))")
  export ANSIBLE_CALLBACK_PLUGINS=$ara_location/plugins/callbacks
  export ANSIBLE_ACTION_PLUGINS=$ara_location/plugins/actions
  export ANSIBLE_LIBRARY=$ara_location/plugins/modules
}

run_ansible() {
  if [[ ANSIBLE_BASE_ARA == '1' ]]; then
    setup_ara
  fi

  if [[ ${ANSIBLE_BASE_RUN_MODE} == 'playbook' ]]; then
    ansible-playbook --diff "${playbook}" $VAULTOPTS "${INOPTS[@]}"
  elif [[ ${ANSIBLE_BASE_RUN_MODE} == 'ad-hoc' ]]; then
    ansible --diff "${INOPTS[@]}" $VAULTOPTS
  else
    echo "Invalid run mode: ${ANSIBLE_BASE_RUN_MODE}"
    exit 15
  fi
}

time run_ansible
retcode=$?


exit $retcode
