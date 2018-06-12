#!/bin/bash
set -e
set -x
shopt -s expand_aliases

alias zold="$1 --ignore-this-stupid-option --ignore-global-config --trace --network=test"

function reserve_port {
  python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
}

function wait_for_port {
  while ! nc -z localhost $1; do
    sleep 1
    ((c++))
    if ((c==10)); then
      echo Port $1 is not available after $c seconds of waiting
      exit -1
    fi
  done
}

function wait_for_file {
  while [ ! -f $1 ]; do
    sleep 1
    ((c++))
    if ((c==10)); then
      echo File $1 not found, giving up after $c seconds of waiting
      exit -1
    fi
  done
}
