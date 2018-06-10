#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1-nohup"

zold --help
