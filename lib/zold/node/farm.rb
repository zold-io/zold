# frozen_string_literal: true

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

require 'time'
require 'open3'
require 'backtrace'
require 'futex'
require 'json'
require 'zold/score'
require_relative '../log'
require_relative '../age'
require_relative '../verbose_thread'
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
    # the necesary parent directories.
    #
    # <tt>lifetime</tt> is the amount of seconds for a score to live in the farm, by default
    # it's the entire day, since the Score expires in 24 hours; can be decreased for the
    # purpose of unit testing.
    def initialize(invoice, cache = File.join(Dir.pwd, 'farm'), log: Log::Quiet.new,
      farmer: Farmers::Plain.new, lifetime: 24 * 60 * 60)
      @log = log
      @cache = File.expand_path(cache)
      @invoice = invoice
      @pipeline = Queue.new
      @farmer = farmer
      @threads = []
      @lifetime = lifetime
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
        @threads.map do |t|
          trace = t.backtrace || []
          [
            "#{t.name}: status=#{t.status}; alive=#{t.alive?}",
            'Vars: ' + t.thread_variables.map { |v| "#{v}=\"#{t.thread_variable_get(v)}\"" }.join('; '),
            "  #{trace.join("\n  ")}"
          ].join("\n")
        end
      ].flatten.join("\n\n")
    end

    def to_json
      {
        threads: @threads.map do |t|
          "#{t.name}/#{t.status}/#{t.alive? ? 'alive' : 'dead'}"
        end.join(', '),
        cleanup: @cleanup.status,
        pipeline: @pipeline.size,
        best: best.map(&:to_mnemo).join(', '),
        alive: @alive
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
    def start(host, port, strength: 8, threads: 8)
      raise 'Block is required for the farm to start' unless block_given?
      @log.info('Zero-threads farm won\'t score anything!') if threads.zero?
      if best.empty?
        @log.info("No scores found in cache at #{@cache}")
      else
        @log.info("#{best.size} scores pre-loaded from #{@cache}, the best is: #{best[0]}")
      end
      cleanup(host, port, strength, threads)
      @alive = true
      @threads = (1..threads).map do |t|
        Thread.new do
          Thread.current.abort_on_exception = true
          Thread.current.name = "f#{t}"
          loop do
            VerboseThread.new(@log).run do
              cycle(host, port, strength, threads)
            end
            break unless @alive
          end
        end
      end
      @cleanup = Thread.new do
        Thread.current.abort_on_exception = true
        Thread.current.name = 'cleanup'
        loop do
          max = 100
          a = (0..max - 1).take_while do
            sleep 0.01
            @alive
          end
          unless a.count == max
            @log.info("It's time to stop the cleanup thread (#{a.count} != #{max}, alive=#{@alive})...")
            break
          end
          VerboseThread.new(@log).run(true) do
            cleanup(host, port, strength, threads)
          end
        end
      end
      @log.info("Farm started with #{@threads.count} threads at #{host}:#{port}, strength is #{strength}")
      return unless block_given?
      begin
        yield(self)
      ensure
        @log.info("Terminating the farm with #{@threads.count} threads...")
        start = Time.now
        finish(@cleanup)
        @threads.each { |t| finish(t) }
        @log.info("Farm stopped in #{Age.new(start)} (threads=#{threads}, strength=#{strength})")
      end
    end

    private

    def finish(thread)
      start = Time.now
      @alive = false
      @log.info("Attempting to terminate the thread \"#{thread.name}\" of the farm...")
      loop do
        delay = Time.now - start
        if thread.join(0.1)
          @log.info("Thread \"#{thread.name}\" peacefully finished in #{Age.new(start)}")
          break
        end
        if delay > 1
          thread.exit
          @log.error("Thread \"#{thread.name}\" forcefully terminated after #{Age.new(start)}")
        end
      end
    end

    def cleanup(host, port, strength, threads)
      scores = load
      before = scores.map(&:value).max.to_i
      save(threads, [Score.new(host: host, port: port, invoice: @invoice, strength: strength)])
      scores = load
      free = scores.reject { |s| @threads.find { |t| t.name == s.to_mnemo } }
      @pipeline << free[0] if @pipeline.size.zero? && !free.empty?
      after = scores.map(&:value).max.to_i
      return unless before != after && !after.zero?
      @log.debug("#{Thread.current.name}: best score of #{scores.count} is #{scores[0]}")
    end

    def cycle(host, port, strength, threads)
      s = []
      loop do
        return unless @alive
        begin
          s << @pipeline.pop(true)
        rescue ThreadError => _
          sleep 0.25
        end
        s.compact!
        break unless s.empty?
      end
      s = s[0]
      return unless s.valid?
      return unless s.host == host
      return unless s.port == port
      return unless s.strength >= strength
      Thread.current.name = s.to_mnemo
      Thread.current.thread_variable_set(:start, Time.now.utc.iso8601)
      score = @farmer.up(s)
      @log.debug("New score discovered: #{score}") if strength > 4
      save(threads, [score])
      cleanup(host, port, strength, threads)
    end

    def save(threads, list = [])
      scores = load + list
      period = @lifetime / [threads, 1].max
      Futex.new(@cache, log: @log).open do |f|
        IO.write(
          f,
          scores.select(&:valid?)
            .reject(&:expired?)
            .sort_by(&:value)
            .reverse
            .uniq(&:time)
            .uniq { |s| (s.age / period).round }
            .map(&:to_s)
            .uniq
            .join("\n")
        )
      end
    end

    def load
      Futex.new(@cache, log: @log).open do |f|
        if File.exist?(f)
          IO.read(f).split(/\n/).map do |t|
            begin
              Score.parse(t)
            rescue StandardError => e
              @log.error(Backtrace.new(e).to_s)
              nil
            end
          end.compact
        else
          []
        end
      end
    end
  end
end
