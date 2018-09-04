#!/bin/bash

port=$(reserve_port)
mkdir server
cd server
zold node --trace --invoice=PULLONSTART@ffffffffffffffff --no-metronome \
  --host=localhost --port=${port} --bind-port=${port} \
  --threads=0 --standalone &
cd ..

wait_for_port ${port}

zold remote clean
zold remote add localhost ${port}

zold --public-key=id_rsa.pub create abcdabcdabcdabcd
zold push abcdabcdabcdabcd
zold remove abcdabcdabcdabcd
zold invoice abcdabcdabcdabcd

second_port=$(reserve_port)
mkdir second
cd second
zold remote clean
zold remote add localhost ${port}
zold node --trace --invoice=abcdabcdabcdabcd --no-metronome \
  --host=localhost --port=${second_port} --bind-port=${second_port} \
  --threads=0 &

wait_for_port ${second_port}

halt_nodes ${second_port} ${port}
