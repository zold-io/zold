# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

FROM ruby:3.3

LABEL "repository"="https://github.com/zold-io/zold"
LABEL "maintainer"="Yegor Bugayenko"
LABEL "version"="0.0.0"

EXPOSE 4096

RUN gem install zold:0.0.0

RUN echo "#!/bin/bash" > node.sh
RUN echo "zold remote reset" >> node.sh
RUN echo "zold node --nohup \044\100" >> node.sh
RUN echo "tail -f zold.log" >> node.sh
RUN chmod +x /node.sh

RUN mkdir /zold
WORKDIR /zold

CMD ["/node.sh"]
