#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1 --ignore-global-config --trace"

port=`python -c 'import socket; s=socket.socket(); s.bind(("", 0)); print(s.getsockname()[1]); s.close()'`

mkdir server
cd server
zold --trace node --invoice=NOPREFIX@ffffffffffffffff \
  --host=localhost --port=${port} --bind-port=${port} \
  --threads=0 --standalone &
pid=$!
trap "kill -9 $pid" EXIT
cd ..

while ! nc -z localhost ${port}; do
  sleep 0.5
  ((c++)) && ((c==20)) && break
done

zold remote clean
zold remote add localhost ${port}
zold remote show

zold create --public-key=id_rsa.pub 0000000000000000
target=`zold create --public-key=id_rsa.pub`
invoice=`zold invoice ${target}`
zold pay --private-key=id_rsa 0000000000000000 ${invoice} 14.99 'To save the world!'
zold propagate 0000000000000000
zold show
zold show 0000000000000000

zold remote show
zold push 0000000000000000
zold fetch 0000000000000000 --ignore-score-weakness
zold diff 0000000000000000
zold merge 0000000000000000
zold clean 0000000000000000
