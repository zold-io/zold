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
require_relative '../log'
require_relative '../score'
require_relative '../verbose_thread'
require_relative '../backtrace'
require_relative '../atomic_file'

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

    def initialize(invoice, cache, log: Log::Quiet.new)
      @log = log
      @cache = cache
      @invoice = invoice
      @pipeline = Queue.new
      @threads = []
      @mutex = Mutex.new
    end

    def best
      load
    end

    def to_text
      @threads.map do |t|
        "#{t.name}: status=#{t.status}; alive=#{t.alive?};\n  #{t.backtrace.join("\n  ")}"
      end.join("\n")
    end

    def to_json
      {
        threads: @threads.map do |t|
          "#{t.name}/#{t.status}/#{t.alive? ? 'A' : 'D'}"
        end.join(', '),
        cleanup: @cleanup.status,
        pipeline: @pipeline.size,
        best: best.map(&:to_mnemo).join(', ')
      }
    end

    def start(host, port, strength: 8, threads: 8)
      @log.info('Zero-threads farm won\'t score anything!') if threads.zero?
      cleanup(host, port, strength, threads)
      @log.info("#{@pipeline.size} scores pre-loaded, the best is: #{best[0]}")
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
      @alive = true
      @cleanup = Thread.new do
        Thread.current.abort_on_exception = true
        Thread.current.name = 'cleanup'
        while @alive
          sleep(60) unless strength == 1 # which will only happen in tests
          VerboseThread.new(@log).run do
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
        @alive = false
        if strength == 1
          @cleanup.join
          @log.info("Cleanup thread finished in #{(Time.now - start).round(2)}s")
        else
          @cleanup.exit
          @log.info("Cleanup thread killed in #{(Time.now - start).round(2)}s")
        end
        @threads.each do |t|
          tstart = Time.now
          t.join(0.1)
          @log.info("Thread #{t.name} finished in #{(Time.now - tstart).round(2)}s")
        end
        @log.info("Farm stopped in #{(Time.now - start).round(2)}s")
      end
    end

    private

    def cleanup(host, port, strength, threads)
      scores = load
      before = scores.map(&:value).max.to_i
      save(threads, [Score.new(time: Time.now, host: host, port: port, invoice: @invoice, strength: strength)])
      scores = load
      push(scores)
      after = scores.map(&:value).max.to_i
      @log.debug("#{Thread.current.name}: best score is #{scores[0]}") if before != after && !after.zero?
    end

    def push(scores)
      free = scores.reject { |s| @threads.find { |t| t.name == s.to_mnemo } }
      @pipeline << free[0] if @pipeline.size.zero? && !free.empty?
    end

    def cycle(host, port, strength, threads)
      s = @pipeline.pop
      return unless s.valid?
      return unless s.host == host
      return unless s.port == port
      return unless s.strength >= strength
      Thread.current.name = s.to_mnemo
      bin = File.expand_path(File.join(File.dirname(__FILE__), '../../../bin/zold'))
      Open3.popen2e("ruby #{bin} --skip-upgrades next \"#{s}\"") do |stdin, stdout, thr|
        @log.debug("Score counting started in process ##{thr.pid}")
        begin
          stdin.close
          buffer = +''
          loop do
            begin
              buffer << stdout.read_nonblock(1024)
            rescue IO::WaitReadable => e
              @log.debug("Still waiting for the data from the score provider: #{e.message}")
            end
            if buffer.end_with?("\n") && thr.value.to_i.zero?
              score = Score.parse(buffer.strip)
              @log.debug("New score discovered: #{score}")
              save(threads, [score])
              cleanup(host, port, strength, threads)
              break
            end
            if stdout.eof?
              raise "Failed to calculate the score (##{thr.value}): #{buffer}" unless thr.value.to_i.zero?
              break
            end
            break unless @alive
            sleep 0.1
          end
        rescue StandardError => e
          @log.error(Backtrace.new(e).to_s)
        ensure
          kill(thr.pid)
        end
      end
    end

    def kill(pid)
      Process.kill('TERM', pid)
      @log.debug("Process ##{pid} killed")
    rescue StandardError => e
      @log.debug("No need to kill process ##{pid} since it's dead already: #{e.message}")
    end

    def save(threads, list = [])
      scores = load + list
      period = 24 * 60 * 60 / [threads, 1].max
      @mutex.synchronize do
        AtomicFile.new(@cache).write(
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
      @mutex.synchronize do
        if File.exist?(@cache)
          AtomicFile.new(@cache).read.split(/\n/)
            .map { |t| parse_score_line(t) }
            .reject(&:zero?)
        else
          []
        end
      end
    end

    def parse_score_line(line)
      Score.parse(line)
    rescue StandardError => e
      @log.error(Backtrace.new(e).to_s)
      Score::ZERO
    end
  end
end
