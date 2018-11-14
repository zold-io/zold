#!/bin/bash

function start_node {
  mkdir $1
  cd $1
  zold remote clean
  zold node $3 --nohup --nohup-command='touch restarted' --nohup-log=log --nohup-max-cycles=0 --nohup-log-truncate=10240 \
    --expose-version=$2 --save-pid=pid --routine-immediately \
    --verbose --trace --invoice=REDEPLOY@ffffffffffffffff \
    --host=127.0.0.1 --port=$1 --bind-port=$1 --threads=1 --strength=20 --memory-dump > /dev/null 2>&1
  wait_for_port $1
  cat pid
  cd ..
}

high=$(reserve_port)
primary=$(start_node ${high} 9.9.9 --standalone)

low=$(reserve_port)
secondary=$(start_node ${low} 1.1.1)

zold remote clean
zold remote add 127.0.0.1 ${high} --home=${low} --skip-ping

trap "halt_nodes ${high}" EXIT

wait_for_file ${low}/restarted

if [ `ps ax | grep zold | grep "${low}"` -eq '' ]; then
  echo "The score finder process is still there, it's a bug"
  exit -1
fi

echo "High node logs (port ${high}):"
cat ${high}/log
echo "Low node logs (port ${low}):"
cat ${low}/log
