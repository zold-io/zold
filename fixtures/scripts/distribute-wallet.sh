#!/bin/bash
# Copyright (c) 2018-2025 Zerocracy
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

function start_node {
  port=$(reserve_port)
  mkdir ${port}
  cd ${port}
  zold node --trace --invoice=DISTRWALLET@ffffffffffffffff --tolerate-edges --tolerate-quorum=1 \
    --host=127.0.0.1 --port=${port} --bind-port=${port} \
    --threads=0 --routine-immediately --never-reboot > log.txt 2>&1 &
  pid=$!
  echo ${pid} > pid
  cd ..
  wait_for_url http://127.0.0.1:${port}/
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
zold --home=${first} remote add 127.0.0.1 ${second}
zold --home=${second} remote clean
zold --home=${second} remote add 127.0.0.1 ${first}

# Locally we create a new root wallet (to avoid negative balance checking)
# and connect our local Zold home to the first remote node. Then, we push
# the wallet to the remote, expecting it to distribute it to the second
# wallet automatically.
zold --public-key=id_rsa.pub create 0000000000000000
zold pay --private-key=id_rsa 0000000000000000 NOPREFIX@aaaabbbbccccdddd 4.95 'For the book'
zold remote clean
zold remote add 127.0.0.1 ${first}
zold push 0000000000000000 --tolerate-edges --tolerate-quorum=1
zold remote clean
zold remote add 127.0.0.1 ${second}

# Here we fetch the wallet from the second remote node. The wallet has
# to be visible there. We are doing a number of attempts with a small
# delay between them, in order to give the first node a chance to distribute
# the wallet.
i=0
until zold fetch 0000000000000000 --ignore-score-weakness --tolerate-edges --tolerate-quorum=1; do
  echo 'Failed to fetch, let us try again'
  ((i++)) || sleep 0
  if ((i==5)); then
    cat ${first}/log.txt
    echo "The wallet has not been distributed, after ${i} attempts"
    exit 9
  fi
  sleep 2
done

# Here we check the JSON of the first node to make sure all status
# indicators are clean.
json=$(curl --silent --show-error http://127.0.0.1:${first})
if [ ! $(echo ${json} | jq -r '.entrance.queue') == "0" ]; then
  echo "The queue is not empty after PUSH, it's a bug"
  exit 5
fi
if [ $(echo ${json} | jq -r '.entrance.history_size') == "0" ]; then
  echo "The history doesn't have a wallet, it's a bug"
  exit 6
fi

# Now, we remove the wallet from the second node and expect the first
# one to "spread" it again, almost immediately. The second node should
# have the wallet very soon.
rm -f ${second}/**/*.z
i=0
until zold fetch 0000000000000000 --ignore-score-weakness --tolerate-edges --tolerate-quorum=1; do
  echo 'Failed to fetch, let us try again'
  ((i++)) || sleep 0
  if ((i==5)); then
    echo "The wallet 0000000000000000 has not been spread, after ${i} attempts, here is the log:"
    cat ${first}/log.txt
    exit 8
  fi
  sleep 2
done
