#!/usr/bin/env bash
# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

mkdir fake
cat > fake/gem <<EOT
#!/usr/bin/env bash
echo "\$*" > "$(pwd)/gem-\$1"
EOT
chmod +x fake/gem
PATH="$(pwd)/fake:${PATH}"

function start_node {
  mkdir "$1"
  cd "$1" || exit
  zold remote clean
  zold node ${3:+"$3"} --nohup --nohup-log=log --nohup-max-cycles=0 --nohup-log-truncate=10240 \
    --expose-version="$2" --save-pid=pid --routine-immediately --tolerate-edges --tolerate-quorum=1 \
    --verbose --trace --invoice=GEMCLEAN@ffffffffffffffff --ignore-empty-remotes \
    --host=127.0.0.1 --port="$1" --bind-port="$1" --threads=1 --strength=20 > /dev/null 2>&1
  wait_for_port "$1"
  cd ..
}

high=$(reserve_port)
start_node "${high}" 9.9.9 --standalone

low=$(reserve_port)
start_node "${low}" 1.1.1

zold remote clean
zold remote add 127.0.0.1 "${high}" --home="${low}" --skip-ping

# shellcheck disable=SC2064
trap "halt_nodes ${high}" EXIT

wait_for_file gem-cleanup

if [ "$(cat gem-cleanup)" != "cleanup zold" ]; then
  echo "The node must run 'gem cleanup zold' after the upgrade, not 'gem $(cat gem-cleanup)'"
  exit 1
fi

echo "Low node logs (port ${low}):"
cat "${low}/log"
