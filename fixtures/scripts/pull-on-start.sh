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
