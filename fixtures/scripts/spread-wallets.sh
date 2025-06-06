#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

function start_node {
  port=$(reserve_port)
  mkdir ${port}
  cd ${port}
  zold remote clean
  zold node --trace --invoice=SPREADWALLETS@ffffffffffffffff --tolerate-edges --tolerate-quorum=1 \
    --host=127.0.0.1 --port=${port} --bind-port=${port} \
    --threads=0 > log.txt 2>&1 &
  pid=$!
  echo ${pid} > pid
  cd ..
  wait_for_url http://localhost:${port}/
  echo ${port}
}

first=$(start_node)
second=$(start_node)
trap "halt_nodes ${first} ${second}" EXIT

zold --home=${first} remote add 127.0.0.1 ${second}
zold --home=${second} remote add 127.0.0.1 ${first}

zold --public-key=id_rsa.pub create 0000000000000000
zold pay --private-key=id_rsa 0000000000000000 NOPREFIX@aaaabbbbccccdddd 4000000z 'To help you, dude!'
zold remote clean
zold remote add 127.0.0.1 ${first}
zold push 0000000000000000 --tolerate-edges --tolerate-quorum=1
zold remote clean
zold remote add 127.0.0.1 ${second}

i=0
until zold fetch 0000000000000000 --ignore-score-weakness --tolerate-edges --tolerate-quorum=1; do
  echo 'Failed to fetch, let us try again'
  ((i++)) || sleep 0
  if ((i==5)); then
    cat ${first}/log.txt
    echo "The wallet has not been distributed, after ${i} attempts"
    exit -1
  fi
  sleep 2
done

json=$(curl --silent --show-error http://127.0.0.1:${first})
if [ ! $(echo ${json} | jq -r '.entrance.queue') == "0" ]; then
  echo "The queue is not empty after PUSH, it's a bug"
  exit -1
fi
if [ ! $(echo ${json} | jq -r '.entrance.history_size') == "1" ]; then
  echo "The history doesn't have a wallet, it's a bug"
  exit -1
fi
