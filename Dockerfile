# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:3.4

LABEL "repository"="https://github.com/zold-io/zold"
LABEL "maintainer"="Yegor Bugayenko"
LABEL "version"="0.32.1"

EXPOSE 4096

RUN gem install zold:0.32.1

RUN printf '%s\n' \
    '#!/usr/bin/env bash' \
    'zold remote reset' \
    'zold node --nohup $@' \
    'tail -f zold.log' \
    > node.sh && \
    chmod +x /node.sh && \
    mkdir /zold
WORKDIR /zold

CMD ["/node.sh"]
