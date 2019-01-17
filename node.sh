#!/bin/bash
zold node --nohup $@
tail -f zold.log
