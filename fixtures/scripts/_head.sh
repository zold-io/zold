#!/bin/bash
set -e
set -x
shopt -s expand_aliases

export RUBYOPT="-W0"

alias zold="$1 --ignore-this-stupid-option --halt-code=test --ignore-global-config --trace --network=test --no-colors --dump-errors"

function reserve_port {
  python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
}

function wait_for_url {
  while ! curl --silent --fail $1 > /dev/null; do
    ((p++)) || sleep 5
    if ((p==30)); then
      echo "URL $1 is not available after $p seconds of waiting"
      exit 12
    fi
    sleep 5
  done
}

function wait_for_port {
  while ! nc -z localhost $1; do
    ((p++)) || sleep 5
    if ((p==30)); then
      echo "Port $1 is not available after $p seconds of waiting"
      exit 13
    fi
    sleep 5
  done
}

function wait_for_file {
  while [ ! -f $1 ]; do
    ((c++)) || sleep 5
    if ((c==30)); then
      echo "File $1 not found, giving up after $c seconds of waiting"
      exit 14
    fi
    sleep 5
  done
}

function halt_nodes {
  for p in "$@"; do
    pid=$(curl --silent "http://localhost:$p/pid?halt=test" || echo 'absent')
    if [[ "${pid}" =~ ^[0-9]+$ ]]; then
      while kill -0 ${pid}; do
        ((c++)) || sleep 5
        if ((c==30)); then
          echo "Waiting for process ${pid} to die"
          exit 15
        fi
        echo "Still waiting for process ${pid} to die, cycle no.${c}"
        sleep 5
      done
      echo "Process ${pid} is dead!"
    fi
    echo "Node at TCP port ${p} stopped!"
  done
}

