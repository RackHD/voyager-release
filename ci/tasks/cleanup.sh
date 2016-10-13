#!/bin/bash

set -e
source voyager-release/ci/tasks/util.sh

check_param VSPHERE_PASSWORD
check_param VSPHERE_SERVER
check_param VSPHERE_USER

VOYAGER_RELEASE=$PWD/voyager-release
COMMIT_HASH=$(get_commit_hash)

sleep "$((${ACCEPTANCE_RESOURCE_TIME_TO_LIVE} * 60))"

function clean_up {
    delete_infrastructure "Voyager-Windows-${COMMIT_HASH}"
    for index in $(seq -f "%03g" 1 ${ACCEPTANCE_NODE_VM_COUNT})
    do
        delete_infrastructure "Voyager-vBMC-${index}-${COMMIT_HASH}"
    done
    delete_infrastructure "" "true"
}

function main {
    clean_up
}

main


