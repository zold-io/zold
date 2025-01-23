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

port=$(reserve_port)

mkdir server
cd server
zold node --trace --invoice=PUSHNPULL@ffffffffffffffff --tolerate-edges --tolerate-quorum=1 \
  --host=127.0.0.1 --port=${port} --bind-port=${port} \
  --threads=0 --standalone 2>&1 &
pid=$!
trap "halt_nodes ${port}" EXIT
cd ..

wait_for_port ${port}

zold remote clean
zold remote add 127.0.0.1 ${port}
zold remote trim
zold remote show

zold --public-key=id_rsa.pub create 0000000000000000
target=$(zold create --public-key=id_rsa.pub)
invoice=$(zold invoice ${target})
zold pay --private-key=id_rsa 0000000000000000 ${invoice} 14.99Z 'To save the world!'
zold propagate
zold propagate 0000000000000000
zold show
zold show 0000000000000000
zold taxes debt 0000000000000000

zold remote show
zold push --tolerate-edges --tolerate-quorum=1
zold push 0000000000000000 --tolerate-edges --tolerate-quorum=1
until zold fetch 0000000000000000 --ignore-score-weakness --tolerate-edges --tolerate-quorum=1; do
  echo 'Failed to fetch, let us try again'
  sleep 1
done
zold fetch --tolerate-edges --tolerate-quorum=1
zold diff 0000000000000000
zold merge
zold merge 0000000000000000
zold clean
zold clean 0000000000000000
zold remove
