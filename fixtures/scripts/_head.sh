#!/bin/bash
set -e
set -x
shopt -s expand_aliases

alias zold="$1 --ignore-this-stupid-option --ignore-global-config --trace --network=test"

function reserve_port {
  python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'
}

