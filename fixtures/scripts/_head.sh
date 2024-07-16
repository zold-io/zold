#!/bin/bash
# Copyright (c) 2018-2024 Zerocracy
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e
set -x
shopt -s expand_aliases

export RUBYOPT="-W0"

alias zold="$1 --ignore-this-stupid-option --halt-code=test --ignore-global-config --trace --network=test --no-colors --dump-errors"

function reserve_port {
  python -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'
}

function wait_for_url {
  i=0
  while ! curl --silent --fail $1 > /dev/null; do
    ((i++)) || sleep 0
    if ((i==30)); then
      echo "URL $1 is not available after ${i} attempts"
      exit 12
    fi
    sleep 2
  done
}

function wait_for_port {
  i=0
  while ! nc -z localhost $1; do
    ((i++)) || sleep 0
    if ((i==30)); then
      echo "Port $1 is not available after ${i} attempts"
      exit 13
    fi
    sleep 2
  done
}

function wait_for_file {
  i=0
  while [ ! -f $1 ]; do
    ((i++)) || sleep 0
    if ((i==30)); then
      echo "File $1 not found, giving up after ${i} attempts"
      exit 14
    fi
    sleep 2
  done
}

function halt_nodes {
  for p in "$@"; do
    pid=$(curl --silent "http://127.0.0.1:$p/pid?halt=test" || echo 'absent')
    if [[ "${pid}" =~ ^[0-9]+$ ]]; then
      i=0
      while kill -0 ${pid}; do
        ((i++)) || sleep 0
        if ((i==30)); then
          echo "Process ${pid} didn't die, it's a bug"
          exit 15
        fi
        echo "Still waiting for process ${pid} to die, attempt no.${i}"
        sleep 2
      done
      echo "Process ${pid} is dead!"
    fi
    echo "Node at TCP port ${p} stopped!"
  done
}

