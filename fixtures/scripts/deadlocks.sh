#!/bin/bash

function start_node {
  port=$(reserve_port)
  mkdir ${port}
  cd ${port}
  zold node --trace --invoice=DEADLOCKS@ffffffffffffffff \
    --host=localhost --port=${port} --bind-port=${port} \
    --threads=0 --no-metronome > log.txt &
  pid=$!
  echo ${pid} > pid
  cd ..
  wait_for_url http://localhost:${port}/
  echo ${port}
}

# We start a few nodes and kill them all at the end of the script. If we
# don't do the TRAP for killing, the test will never end.
first=$(start_node)
second=$(start_node)
third=$(start_node)
trap "halt_nodes ${first} ${second} ${third}" EXIT

# The first node is linked to the second one and the second one
# is linked to the first one, and so on. The --home argument specifies their
# locations.
zold --home=${first} remote clean
zold --home=${first} remote add localhost ${second}
zold --home=${first} remote add localhost ${third}
zold --home=${second} remote clean
zold --home=${second} remote add localhost ${first}
zold --home=${second} remote add localhost ${third}
zold --home=${third} remote clean
zold --home=${third} remote add localhost ${first}
zold --home=${third} remote add localhost ${second}

# We connect the local folder to all nodes
zold remote clean
zold remote add localhost ${first}
zold remote add localhost ${second}
zold remote add localhost ${third}

# Locally we create a new root wallet (to avoid negative balance checking)
# and connect our local Zold home to the first remote node.
# Then we push the wallet to both nodes at the same time and crash
# if any of them fail.
zold --public-key=id_rsa.pub create 0000000000000000
i=0
while true; do
  ((i++))
  if ((i==5)); then break; fi
  zold pay --private-key=id_rsa 0000000000000000 NOPREFIX@aaaabbbbccccdddd 7.99 'For the cookie'
  zold push 0000000000000000
  zold pull 0000000000000000
done

# Here we check the JSON of the first node to make sure all status
# indicators are clean.
json=$(curl --silent --show-error http://localhost:${first})
if [ ! $(echo ${json} | jq -r '.entrance.queue') == "0" ]; then
  echo "The queue is not empty after PUSH, it's a bug"
  echo ${json}
  exit 5
fi
if [ $(echo ${json} | jq -r '.entrance.history_size') == "0" ]; then
  echo "The history doesn't have a wallet, it's a bug"
  echo ${json}
  exit 6
fi
