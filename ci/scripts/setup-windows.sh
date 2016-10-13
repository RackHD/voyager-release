#!/bin/bash
set -e

ROOT_PATH=$PWD
VOYAGER_RELEASE=$PWD/voyager-release
TASKS_FOLDER=$VOYAGER_RELEASE/ci/tasks
KEY_FILE=$ROOT_PATH/ssh.key

source $VOYAGER_RELEASE/ci/tasks/util.sh

COMMIT_HASH=$(get_commit_hash)

cleanUp() {
  cd $TASKS_FOLDER
  terraform destroy -force
}

trap cleanUp ERR

cd $TASKS_FOLDER
export AVAILABLE_IP_ADDRESS=$(get_free_ip)
echo $AVAILABLE_IP_ADDRESS
set -x
echo "$ACCEPTANCE_WINDOWS_SSH_KEY" > $KEY_FILE
chmod 400 $KEY_FILE
cat > windows.tf <<EOF
provider "vsphere" {
  user                 = "${VSPHERE_USER}"
  password             = "${VSPHERE_PASSWORD}"
  vsphere_server       = "${VSPHERE_SERVER}"
  allow_unverified_ssl = true
}
resource "vsphere_virtual_machine" "TestVM" {
  name               = "Voyager-Windows-${COMMIT_HASH}"
  datacenter         = "${ACCEPTANCE_DATACENTER}"
  cluster            = "${ACCEPTANCE_CLUSTER}"
  resource_pool      = "${ACCEPTANCE_RESOURCE_POOL}"
  vcpu = 2
  memory = 16384
  count              = 1
  linked_clone = true
  dns_servers = ${DNS_SERVERS}
  network_interface {
    label = "${ACCEPTANCE_PUBLIC_SUBNET}"
    ipv4_address = "${AVAILABLE_IP_ADDRESS}"
    ipv4_gateway = "${ACCEPTANCE_VM_GATEWAY}"
    ipv4_prefix_length = "24"
  }
  network_interface {
    label = "${ACCEPTANCE_PUBLIC_SUBNET}"
  }
  disk {
    datastore = "${ACCEPTANCE_DATASTORE}"
    template  = "${ACCEPTANCE_WINDOWS_VM_TEMPLATE}"
  }
  provisioner "remote-exec" {
      inline = [
        "echo Hallelujah"
      ]
      connection {
        type = "ssh"
        host = "${AVAILABLE_IP_ADDRESS}"
        user = "${ACCEPTANCE_WINDOWS_USER}"
        private_key = "${ACCEPTANCE_WINDOWS_SSH_KEY}"
      }
  }
}
EOF
set -x
terraform apply
