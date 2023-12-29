#!/bin/bash

# This script is used to update the telemetry folder in the current directory from git.

pushd `dirname $0` > /dev/null

git clone --depth 1 git@github.com:AutoMQ/automq-for-kafka.git automq-for-kafka-tmp
rm -rf ./telemetry
mv automq-for-kafka-tmp/docker/telemetry .
rm -rf automq-for-kafka-tmp

popd > /dev/null

