#!/bin/bash
set -e
ROOT_PATH=$PWD
VOYAGER_RELEASE=$PWD/voyager-release
TASKS_FOLDER=$VOYAGER_RELEASE/ci/tasks

source $VOYAGER_RELEASE/ci/tasks/util.sh

COMMIT_HASH=$(get_commit_hash)

cleanUp() {
  cd $TASKS_FOLDER
  delete_infrastructure
}
trap cleanUp ERR

deploy_infrastructure "Voyager-Windows-${COMMIT_HASH}"