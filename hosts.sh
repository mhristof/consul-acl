#! /usr/bin/env bash
# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -euo pipefail
IFS=$'\n\t'

 aws ec2 describe-instances | jq -r \
  '[
      .Reservations[].Instances[]
      | . as $node
      | {
          ip: ($node.PublicIpAddress),
          name: ($node.Tags[] | select(.Key == "Name").Value),
          group: ($node.Tags[] | select(.Key == "ansible_group").Value),
          leader: ($node.Tags[] | select(.Key == "leader").Value),

        }
   ]
   | group_by( .group)
   | map ({group:.[0].group, nodes:([.[]|"\(.name) leader=\(.leader) ansible_ssh_user=ubuntu ansible_host=\(.ip)"]|join("\n"))})
   | .[] | "[\(.group)]","\(.nodes)"' | grep -v null

exit 0
