#!/bin/bash
zold node --nohup --host=0.0.0.0 $@
tail -f zold.log
