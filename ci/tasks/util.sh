#!/bin/bash
set -e -x

PYTHON_VIRTUAL_ENV=/go/venv/bin/activate

get_free_ip(){
  source ${PYTHON_VIRTUAL_ENV}
    python $VOYAGER_RELEASE/ci/scripts/get_free_ip.py 2>&1
  deactivate
}

get_commit_hash(){
  cd ${VOYAGER_RELEASE}
    git rev-parse --short HEAD
  cd ${ROOT_PATH}
}

check_param() {
  local name=$1
  local value=$(eval echo '$'$name)
  if [ "$value" == 'replace-me' ]; then
    echo "environment variable $name must be set"
    exit 1
  fi
}

get_release_notes() {
  if [ $2 != $3 ]
    then
      echo "$1:" >> ../release-notes.txt
      git log v$2..v$3 --oneline | grep -Ev ':airplane:' >> ../release-notes.txt
      echo "" >> ../release-notes.txt
  fi
}


# $1 is the version number
# $2 is the file destination
function build_docker_compose_file {
cat > $1 <<EOF
version: '2'
services:
  rabbitmq:
    image: rabbitmq:3-management
    ports:
    - "5672:5672"
    - "15672:15672"
    container_name: "rabbitmq"
    hostname: "rabbitmq"
  mysql:
    image: mysql:8.0.0
    ports:
    - "3306:3306"
    container_name: "mysql"
    hostname: "mysql"
    environment:
    - MYSQL_ALLOW_EMPTY_PASSWORD=yes
  ipam:
    image: rackhd/ipam:latest
    container_name: "ipam"
    hostname: "ipam"
    ports:
    - "8000:8000"
    command: "-mongo ipam-mongo:27017"
    depends_on:
    - ipam-mongo
  ipam-mongo:
    image: mongo:3.2.10
    container_name: "ipam-mongo"
    hostname: "ipam-mongo"
  voyager-ipam-service:
    image: rackhd/voyager-ipam-service:${IPAM_SERVICE_VERSION}
    container_name: "voyager-ipam-service"
    hostname: "voyager-ipam-service"
    depends_on:
    - ipam-mongo
  voyager-rackhd-service:
    image: rackhd/voyager-rackhd-service:${RACKHD_SERVICE_VERSION}
    container_name: "voyager-rackhd-service"
    hostname: "voyager-rackhd-service"
    depends_on:
    - rabbitmq
  voyager-inventory-service:
    image: rackhd/voyager-inventory-service:${INVENTORY_SERVICE_VERSION}
    container_name: "voyager-inventory-service"
    hostname: "voyager-inventory-service"
    depends_on:
    - rabbitmq
    - mysql
  voyager-secret-service:
    image: rackhd/voyager-secret-service:${SECRET_SERVICE_VERSION}
    container_name: "voyager-secret-service"
    hostname: "voyager-secret-service"
    depends_on:
    - rabbitmq
  voyager-cisco-engine:
    image: rackhd/voyager-cisco-engine:${CISCO_ENGINE_VERSION}
    container_name: "voyager-cisco-engine"
    hostname: "voyager-cisco-engine"
    depends_on:
    - rabbitmq
  voyager-houston:
    image: rackhd/voyager-houston:${HOUSTON_VERSION}
    ports:
    - "5000:5000"
    - "8080:8080"
    environment:
    - PORT=8080
    container_name: "voyager-houston"
    hostname: "voyager-houston"
    depends_on:
    - rabbitmq
    - voyager-inventory-service
    - voyager-ipam-service
    - voyager-rackhd-service
EOF
}

# Builds the mission-control binaries to run on remote windows machine
function build_mcc {
    cp -r voyager-cli ${PROJECT_VOYAGER_DIR}/voyager-cli
    pushd ${PROJECT_VOYAGER_DIR}/voyager-cli
      make deps
      make build
      cp -r bin/* ${PROJECT_VOYAGER_DIR}/voyager-release/cli
    popd
}

function set_git_global_config {
    echo -e "machine github.com\n  login $GITHUB_USER\n  password $GITHUB_PASSWORD" >> ~/.netrc
    git config --global user.email ${GITHUB_EMAIL}
    git config --global user.name ${GITHUB_USER}
    git config --global push.default current
}

deploy_infrastructure() {
  source ${PYTHON_VIRTUAL_ENV}
  python $VOYAGER_RELEASE/ci/scripts/deploy-acceptance-resources.py \
        -s "${VSPHERE_SERVER}" \
        -u "${VSPHERE_USER}" \
        -p "${VSPHERE_PASSWORD}" \
        --datacenter_name "${ACCEPTANCE_DATACENTER}" \
        --cluster_name "${ACCEPTANCE_CLUSTER}" \
        --vm_name "$1" \
        --vswitch_name "${ACCEPTANCE_VSWITCH_NAME}" \
        -t "$(get_commit_hash)" \
        --datastore_name "${ACCEPTANCE_DATASTORE}"
  deactivate
}

delete_infrastructure() {
  source ${PYTHON_VIRTUAL_ENV}
  python $VOYAGER_RELEASE/ci/scripts/delete-acceptance-resources.py \
        -s "${VSPHERE_SERVER}" \
        -u "${VSPHERE_USER}" \
        -p "${VSPHERE_PASSWORD}" \
        --datacenter_name "${ACCEPTANCE_DATACENTER}" \
        --cluster_name "${ACCEPTANCE_CLUSTER}" \
        --vm_name "$1" \
        --vswitch_name "${ACCEPTANCE_VSWITCH_NAME}" \
        -t "$(get_commit_hash)" \
        --datastore_name "${ACCEPTANCE_DATASTORE}" \
        --delete_network "$2"
  deactivate
}

get_vm_ip() {
  source ${PYTHON_VIRTUAL_ENV}
  python $VOYAGER_RELEASE/ci/scripts/get-ip-for-vm-network.py \
        -s "${VSPHERE_SERVER}" \
        -u "${VSPHERE_USER}" \
        -p "${VSPHERE_PASSWORD}" \
        --vm_name "$1" \
        --port_group_name "$2" \
        -t "$(get_commit_hash)" 2>&1
  deactivate
}
