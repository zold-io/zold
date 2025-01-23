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
  mkdir $1
  cd $1
  zold remote clean
  zold node $3 --nohup --nohup-command='touch restarted' --nohup-log=log --nohup-max-cycles=0 --nohup-log-truncate=10240 \
    --expose-version=$2 --save-pid=pid --routine-immediately --tolerate-edges --tolerate-quorum=1 \
    --verbose --trace --invoice=REDEPLOY@ffffffffffffffff --ignore-empty-remotes \
    --host=127.0.0.1 --port=$1 --bind-port=$1 --threads=1 --strength=20 > /dev/null 2>&1
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
