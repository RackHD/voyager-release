#!/bin/bash

set -e -x
source voyager-release/ci/tasks/util.sh

check_param GITHUB_EMAIL
check_param GITHUB_USER
check_param GITHUB_PASSWORD

function build_binary {
    cp -r $1 ${SOURCE_DIR}/$1
    pushd ${SOURCE_DIR}/$1
      make deps
      make build
      cp bin/* ${WORK_DIR}/build/voyager-release/docker/$1/
    popd
}

function set_env {
    WORK_DIR=${PWD}
    export GOPATH=${PWD}
    SOURCE_DIR=${GOPATH}/src/github.com/RackHD
    mkdir -p ${SOURCE_DIR}

    cp -r voyager-release build/voyager-release
}

function create_version_file {
    export VERSION_NUMBER=$(cut -d "." -f1 version/version)
    echo $VERSION_NUMBER > build/version
}

function main {
    set_env
    set_git_global_config
    create_version_file
    for i in "voyager-houston" "voyager-inventory-service" "voyager-ipam-service" "voyager-rackhd-service" "voyager-secret-service" "voyager-cisco-engine"; do
        build_binary $i
    done
}

main

# Copying over voyager-cisco-engine templates to be baked into the docker image
cp -r voyager-cisco-engine/templates ${WORK_DIR}/build/voyager-release/docker/voyager-cisco-engine
cp -r voyager-cisco-engine/workflows ${WORK_DIR}/build/voyager-release/docker/voyager-cisco-engine
