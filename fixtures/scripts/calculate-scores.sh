#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1 --ignore-global-config --trace"

zold score --host=zold.io --port=4096 --invoice=NOSUFFIX@ffffffffffffffff --strength=2 --max=5
