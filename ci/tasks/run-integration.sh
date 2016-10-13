#!/bin/bash

set -e -x

[[ -s "/home/emc/.gvm/scripts/gvm" ]] >/dev/null 2>/dev/null
source "/home/emc/.gvm/scripts/gvm" >/dev/null 2>/dev/null

PROJECT_PATH=$GOPATH/src/github.com/RackHD
COMPOSE_PATH=ci/integration/docker-compose.yml

cleanUp()
{
  # Don't exit on error here. All commands in this cleanUp must run,
  #   even if some of them fail
  set +e

  # Delete all containers
  docker rm -f $(docker ps -a -q)

  # Delete all images
  docker rmi -f $(docker images -q)

  # Delete any dangling volumes
  docker volume rm $(docker volume ls -qf dangling=true)

  # Clean up all cloned repos
  cd $GOPATH
  rm -rf $GOPATH/src
}

trap cleanUp EXIT

pushd $PROJECT_PATH/voyager-houston
  echo "Testing Houston"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "Houston PASS\n\n"
popd


pushd $PROJECT_PATH/voyager-cli
  echo "Testing Mission Control Center"

  make deps
  make build
  make integration-test

  echo "Mission Control Center PASS\n\n"
popd


pushd $PROJECT_PATH/voyager-inventory-service
  echo "Testing Inventory Service"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "Inventory Service PASS\n\n"
popd

pushd $PROJECT_PATH/voyager-secret-service
  echo "Testing Secret Service"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "Secret Service PASS\n\n"
popd

pushd $PROJECT_PATH/voyager-ipam-service
  echo "Testing IPAM Service"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make build
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "IPAM Service PASS\n\n"
popd


pushd $PROJECT_PATH/voyager-rackhd-service
  echo "Testing RackHD Service"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make build
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "RackHD Service PASS\n\n"
popd

pushd $PROJECT_PATH/voyager-cisco-engine
  echo "Testing Cisco Engine"

  docker-compose -f ${COMPOSE_PATH} create
  docker-compose -f ${COMPOSE_PATH} start

  make deps
  make build
  make integration-test

  docker-compose -f ${COMPOSE_PATH} kill
  # Delete all containers
  docker rm -f $(docker ps -a -q)

  echo "Cisco Engine PASS\n\n"
popd

exit
