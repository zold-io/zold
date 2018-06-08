# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'csv'
require 'uri'
require 'fileutils'
require_relative 'node/farm'

# The list of remotes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # All remotes
  class Remotes
    # The default TCP port all nodes are supposed to use.
    PORT = 4096

    # Empty, for standalone mode
    class Empty
      def all
        []
      end

      def iterate(_)
        # Nothing to do here
      end
    end

    # One remote.
    class Remote
      attr_reader :host, :port
      def initialize(host, port, score, log: Log::Quiet.new)
        @host = host
        @port = port
        @score = score
        @log = log
      end

      def http(path = '/')
        uri = URI("http://#{@host}:#{@port}#{path}")
        Http.new(uri, @score)
      end

      def to_s
        "#{@host}:#{@port}"
      end

      def assert_code(code, response)
        msg = response.message
        return if response.code.to_i == code
        @log.debug("#{response.code} \"#{response.message}\" at \"#{response.body}\"")
        raise "Unexpected HTTP code #{response.code}, instead of #{code}" if msg.empty?
        raise "#{msg} (HTTP code #{response.code}, instead of #{code})"
      end

      def assert_valid_score(score)
        raise "Invalid score #{score}" unless score.valid?
        raise "Expired score #{score}" if score.expired?
      end
    end

    def initialize(file)
      @file = file
    end

    def all
      list = load
      max_score = list.map { |r| r[:score] }.max || 0
      max_score = 1 if max_score.zero?
      max_errors = list.map { |r| r[:errors] }.max || 0
      max_errors = 1 if max_errors.zero?
      list.sort_by do |r|
        (1 - r[:errors] / max_errors) * 5 + (r[:score] / max_score)
      end.reverse
    end

    def clean
      save([])
    end

    def reset
      FileUtils.mkdir_p(File.dirname(@file))
      FileUtils.copy(
        File.join(File.dirname(__FILE__), '../../resources/remotes'),
        @file
      )
    end

    def exists?(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      !load.find { |r| r[:host] == host.downcase && r[:port] == port }.nil?
    end

    def add(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Port can\'t be negative' if port < 0
      raise 'Port can\'t be over 65536' if port > 0xffff
      raise "#{host}:#{port} alread exists" if exists?(host, port)
      list = load
      list << { host: host.downcase, port: port, score: 0 }
      list.uniq! { |r| "#{r[:host]}:#{r[:port]}" }
      save(list)
    end

    def remove(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise "#{host}:#{port} is absent" unless exists?(host, port)
      list = load
      list.reject! { |r| r[:host] == host.downcase && r[:port] == port }
      save(list)
    end

    def iterate(log, farm: Farm::Empty.new)
      best = farm.best[0]
      require_relative 'score'
      score = best.nil? ? Score::ZERO : best
      all.each do |r|
        begin
          yield Remotes::Remote.new(r[:host], r[:port], score, log: log)
        rescue StandardError => e
          error(r[:host], r[:port])
          log.info("#{Rainbow("#{r[:host]}:#{r[:port]}").red}: #{e.message}")
          log.debug(e.backtrace[0..5].join("\n\t"))
        end
      end
    end

    def error(host, port = Remotes::PORT)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise "#{host}:#{port} is absent" unless exists?(host, port)
      list = load
      list.find do |r|
        r[:host] == host.downcase && r[:port] == port
      end[:errors] += 1
      save(list)
    end

    def rescore(host, port, score)
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise "#{host}:#{port} is absent" unless exists?(host, port)
      list = load
      list.find do |r|
        r[:host] == host.downcase && r[:port] == port
      end[:score] = score
      save(list)
    end

    private

    def load
      CSV.read(file).map do |r|
        {
          host: r[0],
          port: r[1].to_i,
          score: r[2].to_i,
          errors: r[3].to_i,
          home: URI("http://#{r[0]}:#{r[1]}/")
        }
      end
    end

    def save(list)
      File.write(
        file,
        list.map do |r|
          [
            r[:host],
            r[:port],
            r[:score],
            r[:errors]
          ].join(',')
        end.join("\n")
      )
    end

    def file
      reset unless File.exist?(@file)
      @file
    end
  end
end
