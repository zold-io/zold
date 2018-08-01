#!/bin/bash

function start_node {
  port=$(reserve_port)
  mkdir ${port}
  cd ${port}
  zold node --trace --invoice=SPREADWALLETS@ffffffffffffffff \
    --host=localhost --port=${port} --bind-port=${port} \
    --threads=0 > log.txt &
  pid=$!
  echo ${pid} > pid
  cd ..
  wait_for_url http://localhost:${port}/
  echo ${port}
}

first=$(start_node)
second=$(start_node)
trap "halt_nodes ${first} ${second}" EXIT

zold --home=${first} remote clean
zold --home=${first} remote add localhost ${second}
zold --home=${second} remote clean
zold --home=${second} remote add localhost ${first}

zold --public-key=id_rsa.pub create 0000000000000000
zold pay --private-key=id_rsa 0000000000000000 NOPREFIX@aaaabbbbccccdddd 4.95 'To help you, dude!'
zold remote add localhost ${first}
zold push 0000000000000000
zold remote clean
zold remote add localhost ${second}

i = 0
until zold fetch 0000000000000000 --ignore-score-weakness; do
  echo 'Failed to fetch, let us try again'
  ((i++))
  if ((i==5)); then
    cat ${first}/log.txt
    echo "The wallet has not been distributed, after ${i} attempts"
    exit -1
  fi
  sleep 2
done

json=$(curl --silent --show-error http://localhost:${first})
if [ ! $(echo ${json} | jq -r '.entrance.queue') == "0" ]; then
  echo "The queue is not empty after PUSH, it's a bug"
  exit -1
fi
if [ ! $(echo ${json} | jq -r '.entrance.history_size') == "1" ]; then
  echo "The history doesn't have a wallet, it's a bug"
  exit -1
fi
if [ ! $(echo ${json} | jq -r '.wallets') == "1" ]; then
  echo "The wallet is not there for some reason, it's a bug"
  exit -1
fi
