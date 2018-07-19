#!/bin/bash

port=$(reserve_port)

zold node --trace --invoice=NOPREFIX@ffffffffffffffff \
  --host=localhost --port=${port} --bind-port=${port} \
  --threads=0 --standalone &
pid=$!
trap "halt_nodes ${port}" EXIT

wait_for_port ${port}

kill -CONT ${pid}

wait_for_file sigdump-${pid}.log
