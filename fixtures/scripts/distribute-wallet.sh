#!/bin/bash

function start_node {
  port=$(reserve_port)
  mkdir ${port}
  cd ${port}
  zold node --trace --invoice=DISTRWALLET@ffffffffffffffff \
    --host=localhost --port=${port} --bind-port=${port} \
    --threads=0 --routine-immediately > log.txt &
  pid=$!
  echo ${pid} > pid
  cd ..
  wait_for_url http://localhost:${port}/
  echo ${port}
}

# We start two nodes and kill them both at the end of the script. If we
# don't do the TRAP for killing, the test will never end.
first=$(start_node)
second=$(start_node)
trap "halt_nodes ${first} ${second}" EXIT

# The first node is linked to the second one and the second one
# is linked to the first one. The --home argument specifies their
# locations.
zold --home=${first} remote clean
zold --home=${first} remote add localhost ${second}
zold --home=${second} remote clean
zold --home=${second} remote add localhost ${first}

# Locally we create a new root wallet (to avoid negative balance checking)
# and connect our local Zold home to the first remote node. Then, we push
# the wallet to the remote, expecting it to distribute it to the second
# wallet automatically.
zold --public-key=id_rsa.pub create 0000000000000000
zold pay --private-key=id_rsa 0000000000000000 NOPREFIX@aaaabbbbccccdddd 4.95 'For the book'
zold remote clean
zold remote add localhost ${first}
zold push 0000000000000000
zold remote clean
zold remote add localhost ${second}

# Here we fetch the wallet from the second remote node. The wallet has
# to be visible there. We are doing a number of attempts with a small
# delay between them, in order to give the first node a chance to distribute
# the wallet.
(( i = 0 ))
until zold fetch 0000000000000000 --ignore-score-weakness; do
  echo 'Failed to fetch, let us try again'
  (( i++ ))
  if (( i==5 )); then
    cat ${first}/log.txt
    echo "The wallet has not been distributed, after ${i} attempts"
    exit 9
  fi
  sleep 5
done

# Here we check the JSON of the first node to make sure all status
# indicators are clean.
json=$(curl --silent --show-error http://localhost:${first})
if [ ! $(echo ${json} | jq -r '.entrance.queue') == "0" ]; then
  echo "The queue is not empty after PUSH, it's a bug"
  exit 5
fi
if [ $(echo ${json} | jq -r '.entrance.history_size') == "0" ]; then
  echo "The history doesn't have a wallet, it's a bug"
  exit 6
fi
if [ ! $(echo ${json} | jq -r '.wallets') == "1" ]; then
  echo "The wallet is not there for some reason, it's a bug"
  exit 7
fi

# Now, we remove the wallet from the second node and expect the first
# one to "spread" it again, almost immediately.
rm ${second}/0000000000000000.z
(( i = 0 ))
until zold fetch 0000000000000000 --ignore-score-weakness; do
  echo 'Failed to fetch, let us try again'
  (( i++ ))
  if (( i==5 )); then
    cat ${first}/log.txt
    echo "The wallet 0000000000000000 has not been spread, after ${i} attempts"
    exit 8
  fi
  sleep 5
done

