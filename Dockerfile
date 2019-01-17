FROM ruby:2.6

RUN gem install zold
EXPOSE 4096

RUN echo "#!/bin/bash" > node.sh
RUN echo "zold node --nohup \044\100" >> node.sh
RUN echo "tail -f zold.log" >> node.sh
RUN chmod +x /node.sh

RUN mkdir /zold
WORKDIR /zold

CMD ["/node.sh"]
