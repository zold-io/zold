#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

zold --help
declare -a commands=(node create invoice remote pay show fetch clean diff merge propagate pull push taxes)
for c in "${commands[@]}"
do
  zold --ignore-global-config --trace $c --help
done
