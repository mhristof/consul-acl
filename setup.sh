#! /usr/bin/env bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

# ansible-playbook consul.yml -e enabled=false -b
# [ -f group_vars/consul/token.yml ] || cat << EOF > group_vars/consul/token.yml
# token: $(uuidgen)
# EOF
# [ -f group_vars/consul-leaders/token.yml ] || cat << EOF > group_vars/consul-leaders/token.yml
# token: $(uuidgen)
# agent: $(cat group_vars/consul/token.yml | cut -d: -f2)
# EOF
# 
ansible-playbook consul.yml -e enabled=true -b
# ansible-playbook consul-acl.yml -l consul-leaders -e token=$TOKEN

exit 0
