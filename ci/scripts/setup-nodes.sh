#!/bin/bash
set -e
ROOT_PATH=$PWD
VOYAGER_RELEASE=$PWD/voyager-release
TASKS_FOLDER=$VOYAGER_RELEASE/ci/tasks

source $VOYAGER_RELEASE/ci/tasks/util.sh

COMMIT_HASH=$(get_commit_hash)

cleanUp() {
  cd $TASKS_FOLDER
  terraform destroy -force
}
trap cleanUp ERR

cat > nodes.tf <<EOF
provider "vsphere" {
  user                 = "${VSPHERE_USER}"
  password             = "${VSPHERE_PASSWORD}"
  vsphere_server       = "${VSPHERE_SERVER}"
  allow_unverified_ssl = true
}
resource "vsphere_virtual_machine" "TestNode" {
  name               = "\${format("Voyager-vBMC-%03d-${COMMIT_HASH}", count.index + 1)}"
  datacenter         = "${ACCEPTANCE_DATACENTER}"
  cluster            = "${ACCEPTANCE_CLUSTER}"
  vcpu               = 4
  memory             = 8192
  skip_customization = true
  count              = ${ACCEPTANCE_NODE_VM_COUNT}
  linked_clone = true
  network_interface {
    label = "${COMMIT_HASH}-RHD-to-Nodes-PG"
    adapter_type = "e1000"
  }
  disk {
    datastore = "${ACCEPTANCE_DATASTORE}"
    template  = "${ACCEPTANCE_NODE_VM_TEMPLATE}"
  }
}
EOF

terraform apply