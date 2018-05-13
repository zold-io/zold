#!/bin/bash
set -x
set -e
shopt -s expand_aliases

alias zold="$1"

zold --help
declare -a commands=(node create invoice remote pay show fetch clean diff merge pull push)
for c in "${commands[@]}"
do
  zold --trace $c --help
done

echo 'DONE'
