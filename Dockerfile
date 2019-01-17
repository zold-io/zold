FROM ruby:2.6

RUN gem install zold
EXPOSE 4096

RUN mkdir /zold
WORKDIR /zold

COPY node.sh /
RUN chmod +x /node.sh

CMD ["/node.sh", "--host=127.0.0.1", "--invoice=17737fee5b825835"]
