#!/bin/bash

port=$(reserve_port)
mkdir server
cd server
zold remote clean
zold node --trace --invoice=PULLONSTART@ffffffffffffffff --no-metronome --tolerate-edges --tolerate-quorum=1 \
  --host=127.0.0.1 --port=${port} --bind-port=${port} \
  --threads=0 --standalone --pretty=full 2>&1 &
cd ..

wait_for_port ${port}

zold remote clean
zold remote add 127.0.0.1 ${port}

zold --public-key=id_rsa.pub create abcdabcdabcdabcd
zold push abcdabcdabcdabcd --tolerate-edges --tolerate-quorum=1
zold remove abcdabcdabcdabcd
zold invoice abcdabcdabcdabcd --tolerate-edges --tolerate-quorum=1

second_port=$(reserve_port)
mkdir second
cd second
zold remote clean
zold remote add 127.0.0.1 ${port}
zold node --trace --invoice=abcdabcdabcdabcd --no-metronome --tolerate-edges --tolerate-quorum=1 \
  --host=127.0.0.1 --port=${second_port} --bind-port=${second_port} \
  --threads=0 &

wait_for_port ${second_port}

halt_nodes ${second_port} ${port}
