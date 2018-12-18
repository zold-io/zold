#!/bin/sh

./bin/zold node --no-colors --trace --dump-errors --skip-oom \
    --bind-port=$PORT --port=80 --host=b1.zold.io --threads=0 \
    --invoice=ML5Ern7m@912ecc24b32dbe74 --never-reboot
