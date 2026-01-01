# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:4.0

LABEL "repository"="https://github.com/zold-io/zold"
LABEL "maintainer"="Yegor Bugayenko"
LABEL "version"="0.0.0"

EXPOSE 4096

RUN gem install zold:0.0.0

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
