#!/bin/bash

set -e
source voyager-release/ci/tasks/util.sh

check_param ACCEPTANCE_WINDOWS_SSH_KEY
check_param ACCEPTANCE_PUBLIC_SUBNET
check_param ACCEPTANCE_WINDOWS_USER
check_param GITHUB_USER
check_param GITHUB_PASSWORD
check_param GITHUB_EMAIL
check_param VSPHERE_PASSWORD
check_param VSPHERE_SERVER
check_param VSPHERE_USER

ROOT_PATH=$PWD
VOYAGER_RELEASE=$PWD/voyager-release
MCC_RELEASE=$PWD/mcc-release

export WATS_ENV_NUM=$(cat $PWD/wats-env-pool/metadata)
export VOYAGER_VERSION=$(cat $PWD/version/version)
export HOUSTON_VERSION=$(cat $PWD/voyager-houston-version/version)
export INVENTORY_SERVICE_VERSION=$(cat $PWD/voyager-inventory-service-version/version)
export IPAM_SERVICE_VERSION=$(cat $PWD/voyager-ipam-service-version/version)
export RACKHD_SERVICE_VERSION=$(cat $PWD/voyager-rackhd-service-version/version)
export CISCO_ENGINE_VERSION=$(cat $PWD/voyager-cisco-engine-version/version)
export SECRET_SERVICE_VERSION=$(cat $PWD/voyager-secret-service-version/version)

export ACCEPTANCE_WINDOWS_IP=$(get_vm_ip "Voyager-Windows-${WATS_ENV_NUM}" "${ACCEPTANCE_PUBLIC_SUBNET}")

# Unzips voyager-cli release zip and puts the binaries in their proper paths
function unzip_mcc {
    apt-get install unzip
    pushd $MCC_RELEASE
        unzip voyager-cli*.zip
    popd

    cp -r $MCC_RELEASE/bin/* $VOYAGER_RELEASE/cli/
}

# Sets up the environment variables for the script to use
function set_env {
    export REMOTE_GOPATH=C:/cygwin64/home/cia/workspace/gopath
    export REMOTE_PROJECT_PATH=${REMOTE_GOPATH}/src/github.com/RackHD
    export KEY_FILE_PATH=${PWD}/ssh.key
    echo "${ACCEPTANCE_WINDOWS_SSH_KEY}" > ${KEY_FILE_PATH}
    chmod 400 ${KEY_FILE_PATH}

    export GOPATH=${PWD}
    PROJECT_VOYAGER_DIR=${GOPATH}/src/github.com/RackHD
    mkdir -p ${PROJECT_VOYAGER_DIR}

    cp -r voyager-release ${PROJECT_VOYAGER_DIR}
}

# Copies over updated voyager-release repo to run on remote windows machine
function test_setup {
    echo "Copying over local project directory to remote machine..."

    ssh -i ${KEY_FILE_PATH} -o "StrictHostKeyChecking no" ${ACCEPTANCE_WINDOWS_USER}@${ACCEPTANCE_WINDOWS_IP} "rm -rf ${REMOTE_PROJECT_PATH} && mkdir -p ${REMOTE_PROJECT_PATH}"
    scp -i ${KEY_FILE_PATH} -o "StrictHostKeyChecking no" -r ${PROJECT_VOYAGER_DIR}/voyager-release ${ACCEPTANCE_WINDOWS_USER}@${ACCEPTANCE_WINDOWS_IP}:${REMOTE_PROJECT_PATH}
}

# Runs acceptance python on remote windows machine
function run_tests {
    ssh -i ${KEY_FILE_PATH} \
    -o "StrictHostKeyChecking no" ${ACCEPTANCE_WINDOWS_USER}@${ACCEPTANCE_WINDOWS_IP} \
    "GITHUB_USERNAME=${GITHUB_USER} \
     GITHUB_PASSWORD=${GITHUB_PASSWORD} \
     GOPATH=$REMOTE_GOPATH \
     VSPHERE_SERVER=$VSPHERE_SERVER \
     VSPHERE_USER=$VSPHERE_USER \
     VSPHERE_PASSWORD=$VSPHERE_PASSWORD \
     ACCEPTANCE_NODE_VM_COUNT=$ACCEPTANCE_NODE_VM_COUNT \
     WATS_ENV_NUM=$WATS_ENV_NUM \
     python ${REMOTE_PROJECT_PATH}/voyager-release/ci/scripts/run-acceptance-in-windows.py"
}

function clean_up {
    # Stage lock for removal
    cp $ROOT_PATH/wats-env-pool/metadata $ROOT_PATH/trash
    cp $ROOT_PATH/wats-env-pool/name $ROOT_PATH/trash
}

function main {
    unzip_mcc
    set_env
    set_git_global_config
    echo "Building docker-compose file for Voyager version: v${VOYAGER_VERSION}"
    build_docker_compose_file ${PROJECT_VOYAGER_DIR}/voyager-release/docker/docker-compose.yml
    test_setup
    run_tests
    clean_up
}

main


