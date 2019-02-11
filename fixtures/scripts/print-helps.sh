#!/bin/bash

zold --help
declare -a commands=(node create invoice remote pay show fetch clean diff rebase merge propagate pull push taxes)
for c in "${commands[@]}"
do
  zold --ignore-global-config --trace $c --help
done
