#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1"

port=`python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'`

mkdir server
cd server
zold --trace node --host=localhost --port=${port} --bind-port=${port} --threads=0 --standalone &
pid=$!
trap "kill -9 $pid" EXIT
cd ..

while ! nc -z localhost ${port}; do
  sleep 0.5
  ((c++)) && ((c==20)) && break
done

zold --trace remote clean
zold --trace remote add localhost ${port}
zold --trace remote show

zold --trace --public-key id_rsa.pub create 0000000000000000
target=`zold --public-key id_rsa.pub create`
invoice=`zold invoice ${target}`
zold --trace --private-key id_rsa pay 0000000000000000 ${invoice} 14.99 'To save the world!'
zold --trace propagate 0000000000000000
zold --trace show
zold --trace show 0000000000000000

zold --trace remote show
zold --trace push 0000000000000000
zold --trace fetch 0000000000000000 --ignore-score-weakness
zold --trace diff 0000000000000000
zold --trace merge 0000000000000000
zold --trace clean 0000000000000000
