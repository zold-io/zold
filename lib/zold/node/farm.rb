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

require 'time'
require 'open3'
require 'backtrace'
require 'futex'
require 'concurrent'
require 'json'
require 'zold/score'
require_relative '../log'
require_relative '../thread_pool'
require_relative '../age'
require_relative '../endless'
require_relative 'farmers'

# The farm of scores.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Farm
  class Farm
    # Empty farm
    class Empty
      def best
        []
      end
    end

    # Makes an instance of a farm. There should be only farm in the entire
    # application, but you can, of course, start as many of them as necessary for the
    # purpose of unit testing.
    #
    # <tt>cache</tt> is the file where the farm will keep all the scores it
    # manages to find. If the file is absent, it will be created, together with
    # the necessary parent directories.
    #
    # <tt>lifetime</tt> is the amount of seconds for a score to live in the farm, by default
    # it's the entire day, since the Score expires in 24 hours; can be decreased for the
    # purpose of unit testing.
    def initialize(invoice, cache = File.join(Dir.pwd, 'farm'), log: Log::NULL,
      farmer: Farmers::Plain.new, lifetime: 24 * 60 * 60, strength: Score::STRENGTH)
      @log = log
      @cache = File.expand_path(cache)
      @invoice = invoice
      @pipeline = Queue.new
      @farmer = farmer
      @threads = ThreadPool.new('farm', log: log)
      @lifetime = lifetime
      @strength = strength
    end

    # Returns the list of best scores the farm managed to find up to now. The
    # list is NEVER empty, even if the farm has just started. If it's empty,
    # it's definitely a bug. If the farm is just fresh start, the list will
    # contain a single score with a zero value.
    def best
      load
    end

    def to_text
      [
        "Current time: #{Time.now.utc.iso8601}",
        "Ruby processes: #{`ps ax | grep zold | wc -l`}",
        JSON.pretty_generate(to_json),
        @threads.to_s
      ].flatten.join("\n\n")
    end

    # Renders the Farm into JSON to show for the end-user in front.rb.
    def to_json
      {
        threads: @threads.to_json,
        pipeline: @pipeline.size,
        best: best.map(&:to_mnemo).join(', '),
        farmer: @farmer.class.name
      }
    end

    # Starts a farm, all threads, and yields the block provided. You are
    # supposed to use it only with the block:
    #
    #  Farm.new.start('example.org', 4096) do |farm|
    #    score = farm.best[0]
    #    # Everything else...
    #  end
    #
    # The farm will stop all its threads and close all resources safely
    # right after the block provided exists.
    def start(host, port, threads: Concurrent.processor_count)
      raise 'Block is required for the farm to start' unless block_given?
      @log.info('Zero-threads farm won\'t score anything!') if threads.zero?
      if best.empty?
        @log.info("No scores found in the cache at #{@cache}")
      else
        @log.info("#{best.size} scores pre-loaded from #{@cache}, the best is: #{best[0]}")
      end
      (1..threads).map do |t|
        @threads.add do
          Thread.current.thread_variable_set(:tid, t.to_s)
          Endless.new("f#{t}", log: @log).run do
            cycle(host, port, threads)
          end
        end
      end
      unless threads.zero?
        ready = false
        @threads.add do
          Endless.new('cleanup', log: @log).run do
            cleanup(host, port, threads)
            ready = true
            sleep(1)
          end
        end
        loop { break if ready }
      end
      if threads.zero?
        cleanup(host, port, threads)
        @log.info("Farm started with no threads (there will be no score) at #{host}:#{port}")
      else
        @log.info("Farm started with #{@threads.count} threads (one for cleanup) \
at #{host}:#{port}, strength is #{@strength}")
      end
      begin
        yield(self)
      ensure
        @threads.kill
      end
    end

    private

    def cleanup(host, port, threads)
      scores = load
      before = scores.map(&:value).max.to_i
      save(host, port, threads, [Score.new(host: host, port: port, invoice: @invoice, strength: @strength)])
      scores = load
      free = scores.reject { |s| @threads.exists?(s.to_mnemo) }
      @pipeline << free[0] if @pipeline.size.zero? && !free.empty?
      after = scores.map(&:value).max.to_i
      return unless before != after && !after.zero?
      @log.debug("#{Thread.current.name}: best score of #{scores.count} is #{scores[0].reduced(4)}")
    end

    def cycle(host, port, threads)
      s = []
      loop do
        begin
          s << @pipeline.pop(true)
        rescue ThreadError => _
          sleep(0.25)
        end
        s.compact!
        break unless s.empty?
      end
      s = s[0]
      return unless s.valid?
      return unless s.host == host
      return unless s.port == port
      return unless s.strength >= @strength
      Thread.current.name = s.to_mnemo
      Thread.current.thread_variable_set(:start, Time.now.utc.iso8601)
      score = @farmer.up(s)
      @log.debug("New score discovered: #{score}") if @strength > 4
      save(host, port, threads, [score])
      cleanup(host, port, threads)
    end

    def save(host, port, threads, list = [])
      scores = load + list
      period = @lifetime / [threads, 1].max
      body = scores.select(&:valid?)
        .reject(&:expired?)
        .reject { |s| s.strength < @strength }
        .select { |s| s.host == host }
        .select { |s| s.port == port }
        .select { |s| s.invoice == @invoice }
        .sort_by(&:value)
        .reverse
        .uniq(&:time)
        .uniq { |s| (s.age / period).round }
        .map(&:to_s)
        .uniq
        .join("\n")
      Futex.new(@cache).open { |f| IO.write(f, body) }
    end

    def load
      return [] unless File.exist?(@cache)
      Futex.new(@cache).open(false) { |f| IO.readlines(f, "\n") }.reject(&:empty?).map do |t|
        Score.parse(t)
      rescue StandardError => e
        @log.error(Backtrace.new(e).to_s)
        nil
      end.compact
    end
  end
end
