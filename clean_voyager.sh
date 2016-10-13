#!/usr/bin/env bash
set -e

pushd vagrant/rackhd
  vagrant destroy -f
popd

pushd vagrant/voyager
  vagrant destroy -f
popd
