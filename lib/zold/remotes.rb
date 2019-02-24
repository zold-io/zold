# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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

require 'concurrent'
require 'csv'
require 'uri'
require 'net/http'
require 'time'
require 'futex'
require 'fileutils'
require 'backtrace'
require 'zold/score'
require_relative 'age'
require_relative 'http'
require_relative 'hands'
require_relative 'thread_pool'
require_relative 'node/farm'

# The list of remotes.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # One remote.
  class RemoteNode
    # When something is wrong with the assertion
    class CantAssert < StandardError; end

    attr_reader :touched

    def initialize(host:, port:, score:, idx:, master:, network: 'test', log: Log::NULL)
      @host = host
      @port = port
      @score = score
      @idx = idx
      @master = master
      @network = network
      @log = log
      @touched = false
    end

    def http(path = '/')
      @touched = true
      Http.new(uri: "http://#{@host}:#{@port}#{path}", score: @score, network: @network)
    end

    def master?
      @master
    end

    def to_s
      "#{@host}:#{@port}/#{@idx}"
    end

    def to_mnemo
      "#{@host}:#{@port}"
    end

    def assert_code(code, response)
      msg = response.status_line.strip
      return if response.status.to_i == code
      if response.headers && response.headers['X-Zold-Error']
        raise CantAssert, "Error ##{response.status} \"#{response.headers['X-Zold-Error']}\" \
at #{response.headers['X-Zold-Path']}"
      end
      raise CantAssert, "Unexpected HTTP code #{response.status}, instead of #{code}" if msg.empty?
      raise CantAssert, "#{msg} (HTTP code #{response.status}, instead of #{code})"
    end

    def assert_valid_score(score)
      raise CantAssert, "Invalid score #{score.reduced(4)}" unless score.valid?
      raise CantAssert, "Expired score (#{Age.new(score.time)}) #{score.reduced(4)}" if score.expired?
    end

    def assert_score_ownership(score)
      raise CantAssert, "Masqueraded host #{@host} as #{score.host}: #{score.reduced(4)}" if @host != score.host
      raise CantAssert, "Masqueraded port #{@port} as #{score.port}: #{score.reduced(4)}" if @port != score.port
    end

    def assert_score_strength(score)
      return if score.strength >= Score::STRENGTH
      raise CantAssert, "Score #{score.strength} is too weak (<#{Score::STRENGTH}): #{score.reduced(4)}"
    end

    def assert_score_value(score, min)
      raise CantAssert, "Score #{score.value} is too small (<#{min}): #{score.reduced(4)}" if score.value < min
    end
  end

  # All remotes
  class Remotes
    # The default TCP port all nodes are supposed to use.
    PORT = 4096

    # At what amount of errors we delete the remote automatically
    TOLERANCE = 8

    # Default number of nodes to fetch.
    MAX_NODES = 16

    # Default nodes and their ports
    MASTERS = CSV.read(File.expand_path(File.join(File.dirname(__FILE__), '../../resources/masters')))
    private_constant :MASTERS

    # Empty, for standalone mode
    class Empty
      def initialize
        # Nothing to init here
      end

      def all
        []
      end

      def iterate(_)
        # Nothing to do here
      end

      def mtime
        Time.now
      end
    end

    def initialize(file:, network: 'test', timeout: 60)
      @file = file
      @network = network
      @timeout = timeout
    end

    def all
      list = Futex.new(@file).open(false) { load }
      max_score = list.map { |r| r[:score] }.max || 0
      max_score = 1 if max_score.zero?
      max_errors = list.map { |r| r[:errors] }.max || 0
      max_errors = 1 if max_errors.zero?
      list.sort_by do |r|
        (1 - r[:errors] / max_errors) * 5 + (r[:score] / max_score)
      end.reverse
    end

    def clean
      modify { [] }
    end

    def masters
      MASTERS.each do |r|
        if block_given?
          next unless yield(r[0], r[1].to_i)
        end
        add(r[0], r[1].to_i)
      end
    end

    def exists?(host, port = PORT)
      assert_host_info(host, port)
      list = Futex.new(@file).open(false) { load }
      !list.find { |r| r[:host] == host.downcase && r[:port] == port }.nil?
    end

    def add(host, port = PORT)
      assert_host_info(host, port)
      modify do |list|
        list + [{ host: host.downcase, port: port, score: 0, errors: 0 }]
      end
      unerror(host, port)
    end

    def remove(host, port = PORT)
      assert_host_info(host, port)
      modify do |list|
        list.reject { |r| r[:host] == host.downcase && r[:port] == port }
      end
    end

    # Go through the list of remotes and call a provided block for each
    # of them. See how it's used, for example, in fetch.rb.
    def iterate(log, farm: Farm::Empty.new)
      raise 'Log can\'t be nil' if log.nil?
      raise 'Farm can\'t be nil' if farm.nil?
      Hands.exec(Concurrent.processor_count * 4, all) do |r, idx|
        Thread.current.name = "remotes-#{idx}@#{r[:host]}:#{r[:port]}"
        start = Time.now
        best = farm.best[0]
        node = RemoteNode.new(
          host: r[:host],
          port: r[:port],
          score: best.nil? ? Score::ZERO : best,
          idx: idx,
          master: master?(r[:host], r[:port]),
          log: log,
          network: @network
        )
        begin
          yield node
          raise 'Took too long to execute' if (Time.now - start).round > @timeout
          unerror(r[:host], r[:port]) if node.touched
        rescue StandardError => e
          error(r[:host], r[:port])
          log.info("#{Rainbow(node).red}: \"#{e.message.strip}\" in #{Age.new(start)}")
          log.debug(Backtrace.new(e).to_s)
          remove(r[:host], r[:port]) if r[:errors] > TOLERANCE
        end
      end
    end

    def error(host, port = PORT)
      assert_host_info(host, port)
      if_present(host, port) { |r| r[:errors] += 1 }
    end

    def unerror(host, port = PORT)
      assert_host_info(host, port)
      if_present(host, port) do |remote|
        remote[:errors] -= 1 if (remote[:errors]).positive?
      end
    end

    def rescore(host, port, score)
      assert_host_info(host, port)
      raise 'Score can\'t be nil' if score.nil?
      raise 'Score has to be of type Integer' unless score.is_a?(Integer)
      if_present(host, port) { |r| r[:score] = score }
      unerror(host, port)
    end

    def mtime
      File.exist?(@file) ? File.mtime(@file) : Time.now
    end

    def master?(host, port)
      !MASTERS.find { |r| r[0] == host && r[1].to_i == port }.nil?
    end

    private

    def modify
      FileUtils.mkdir_p(File.dirname(@file))
      Futex.new(@file).open do
        list = yield(load)
        IO.write(
          @file,
          list.uniq { |r| "#{r[:host]}:#{r[:port]}" }.map do |r|
            [
              r[:host],
              r[:port],
              r[:score],
              r[:errors]
            ].join(',')
          end.join("\n")
        )
      end
    end

    def if_present(host, port)
      modify do |list|
        remote = list.find { |r| r[:host] == host.downcase && r[:port] == port }
        return unless remote
        yield remote
        list
      end
    end

    def load
      if File.exist?(@file)
        raw = CSV.read(@file).map do |row|
          {
            host: row[0],
            port: row[1].to_i,
            score: row[2].to_i,
            errors: row[3].to_i,
            master: master?(row[0], row[1].to_i)
          }
        end
        raw.reject { |r| !r[:host] || r[:port].zero? }.map do |r|
          r[:home] = URI("http://#{r[:host]}:#{r[:port]}/")
          r
        end
      else
        []
      end
    end

    def assert_host_info(host, port)
      raise 'Host can\'t be nil' if host.nil?
      raise 'Host can\'t be empty' if host.empty?
      raise 'Port can\'t be nil' if port.nil?
      raise 'Port has to be of type Integer' unless port.is_a?(Integer)
      raise 'Port can\'t be zero' if port.zero?
      raise 'Port can\'t be negative' if port.negative?
      raise 'Port can\'t be over 65536' if port > 0xffff
    end
  end
end
