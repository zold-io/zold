#!/bin/bash
set -e
set -x
shopt -s expand_aliases

export RUBYOPT="-W0"

alias zold="$1 --ignore-this-stupid-option --halt-code=test --ignore-global-config --trace --network=test --no-colors"

function reserve_port {
  python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
}

function wait_for_url {
  while ! curl --silent --fail $1 > /dev/null; do
    ((p++)) || sleep 1
    if ((p==30)); then
      echo URL $1 is not available after $p seconds of waiting
      exit -1
    fi
    sleep 1
  done
}

function wait_for_port {
  while ! nc -z localhost $1; do
    ((p++)) || sleep 1
    if ((p==30)); then
      echo Port $1 is not available after $p seconds of waiting
      exit -1
    fi
    sleep 1
  done
}

function wait_for_file {
  while [ ! -f $1 ]; do
    ((c++)) || sleep 1
    if ((c==30)); then
      echo File $1 not found, giving up after $c seconds of waiting
      exit -1
    fi
    sleep 1
  done
}

function halt_nodes {
  for p in "$@"; do
    curl --silent "http://localhost:$p/version?halt=test" || echo "Failed to halt at TCP ${p}"
  done
}

