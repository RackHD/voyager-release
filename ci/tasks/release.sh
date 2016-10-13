#!/bin/bash

set -e -x
source voyager-release/ci/tasks/util.sh

check_param GITHUB_EMAIL
check_param GITHUB_USER
check_param GITHUB_PASSWORD

VOYAGER_RELEASE=$PWD/voyager-release
MCC_RELEASE=$PWD/mcc-release

export VOYAGER_VERSION=$(cat $PWD/version/version)
export HOUSTON_VERSION=$(cat $PWD/voyager-houston-version/version)
export INVENTORY_SERVICE_VERSION=$(cat $PWD/voyager-inventory-service-version/version)
export IPAM_SERVICE_VERSION=$(cat $PWD/voyager-ipam-service-version/version)
export RACKHD_SERVICE_VERSION=$(cat $PWD/voyager-rackhd-service-version/version)
export CISCO_ENGINE_VERSION=$(cat $PWD/voyager-cisco-engine-version/version)
export SECRET_SERVICE_VERSION=$(cat $PWD/voyager-secret-service-version/version)

# Unzips voyager-cli release zip and puts the binaries in their proper paths
function unzip_mcc {
    apt-get install unzip
    pushd ${MCC_RELEASE}
        unzip voyager-cli*.zip
    popd

    cp -r ${MCC_RELEASE}/bin/* ${VOYAGER_RELEASE}/cli/
}

function prepare_promote_candidate {
    pushd ${VOYAGER_RELEASE}
      git add docker/docker-compose.yml cli/*
      git commit -m ":airplane: New release v${VOYAGER_VERSION}"
    popd

    cp -r ${VOYAGER_RELEASE} promote

    pushd promote
      printf "Voyager Release v${VOYAGER_VERSION}" > name
      printf "v${VOYAGER_VERSION}" > tag
    popd
}

function main {
    unzip_mcc
    set_git_global_config
    echo "Building docker-compose file for Voyager version: v${VOYAGER_VERSION}"
    build_docker_compose_file ${VOYAGER_RELEASE}/docker/docker-compose.yml
    prepare_promote_candidate
}

main


#touch ${source_dir}/release-notes.txt
#
#pushd build/voyager-release
#  release_version=`cat version | tr -d '\n'`
#  last_mcc=`git show v$((release_version)) -s --format=%B | grep voyager-cli | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_cisco=`git show v$((release_version)) -s --format=%B | grep voyager-cisco-engine | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_houston=`git show v$((release_version)) -s --format=%B | grep voyager-houston | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_inventory=`git show v$((release_version)) -s --format=%B | grep voyager-inventory-service | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_ipam=`git show v$((release_version)) -s --format=%B | grep voyager-ipam-service | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_rackhd=`git show v$((release_version)) -s --format=%B | grep voyager-rackhd-service | cut -d ':' -f2 | cut -d 'v' -f2`
#  last_secret=`git show v$((release_version)) -s --format=%B | grep voyager-secret-service | cut -d ':' -f2 | cut -d 'v' -f2`
#popd
