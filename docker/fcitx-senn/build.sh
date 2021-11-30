#!/bin/bash

DIR=../../
docker build $DIR -f ./ecl-builder.dockerfile -t ecl-builder   && \
docker build $DIR -f ./kkc-builder.dockerfile -t kkc-builder   && \
docker build $DIR -f ./menu-builder.dockerfile -t menu-builder && \
docker build $DIR -f ./Dockerfile -t fcitx-senn-builder        && \
docker run  -v $PWD:/host --rm -t fcitx-senn-builder
