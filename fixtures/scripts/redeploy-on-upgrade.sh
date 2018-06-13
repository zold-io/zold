#!/bin/bash

function start_node {
  mkdir $1
  cd $1
  zold remote clean
  zold node $3 --nohup --nohup-command='touch restarted' --nohup-log=log \
    --expose-version=$2 --save-pid=pid --routine-immediately \
    --verbose --trace --invoice=NOPREFIX@ffffffffffffffff \
    --host=localhost --port=$1 --bind-port=$1 --threads=0 > /dev/null 2>&1
  wait_for_port $1
  cat pid
  cd ..
}

high=$(reserve_port)
primary=$(start_node ${high} 9.9.9 --standalone)

low=$(reserve_port)
secondary=$(start_node ${low} 1.1.1)
zold remote add localhost ${high} --home=${low}

trap "kill -9 ${primary}; kill -9 ${secondary}" EXIT

wait_for_file ${low}/restarted

echo "High node logs (port ${high}):"
cat ${high}/log
echo "Low node logs (port ${low}):"
cat ${low}/log
