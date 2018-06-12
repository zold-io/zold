#!/bin/bash

port=$(reserve_port)

zold node --trace --invoice=NOPREFIX@ffffffffffffffff \
  --host=localhost --port=${port} --bind-port=${port} \
  --threads=0 --standalone &
pid=$!
trap "kill -9 $pid" EXIT

wait_for_port ${port}

kill -CONT ${pid}

wait_for_file sigdump-${pid}.log
