#
#

setup:
	ansible-playbook consul.yml -e enabled=false -b
.PHONY: setup

ping: .bootstrap
	ansible all -m ping
.PHONY: ping

.bootstrap: bootstrap.yml hosts
	ansible-playbook -b bootstrap.yml
	touch .bootstrap

hosts: terraform.tfstate hosts.sh
	./hosts.sh > hosts

terraform.tfstate: tf.plan
	terraform apply tf.plan

tf.plan: main.tf
	terraform plan -out tf.plan

clean:
	terraform destroy -force
	-rm tf.plan
	-rm .bootstrap
	-rm hosts
	-rm -r group_vars/all/tokens.yml
