#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1 --ignore-global-config --trace"

zold --help
declare -a commands=(node create invoice remote pay show fetch clean diff merge propagate pull push)
for c in "${commands[@]}"
do
  zold --ignore-global-config --trace $c --help
done
