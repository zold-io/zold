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
require_relative '../log'
require_relative '../score'
require_relative '../verbose_thread'
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
      @scores = []
      @threads = []
      @best = []
      @mutex = Mutex.new
    end

    def best
      @mutex.synchronize do
        @best.to_a
      end
    end

    def to_text
      @threads.map do |t|
        "#{t.name}: status=#{t.status}; alive=#{t.alive};\n  #{t.backtrace.join("\n  ")}"
      end.join("\n")
    end

    def to_json
      {
        threads: @threads.map do |t|
          "#{t.name}/#{t.status}/{t.alive? ? 'A' : 'D'}"
        end.join(', '),
        scores: @scores.size,
        best: @best.map(&:value).join(', '),
        history: history.count
      }
    end

    def start(host, port, strength: 8, threads: 8)
      @log.debug('Zero-threads farm won\'t score anything!') if threads.zero?
      @scores = Queue.new
      h = history(threads)
      h.each { |s| @scores << s }
      @best << (h[0] || Score.new(Time.now, host, port, @invoice, strength: strength))
      @log.info("#{@scores.size} scores pre-loaded, the best is: #{@best[0]}")
      @threads = (1..threads).map do |t|
        Thread.new do
          Thread.current.name = "f#{t}"
          loop do
            VerboseThread.new(@log).run do
              cycle(host, port, strength, threads)
            end
          end
        end
      end
      @threads << Thread.new do
        Thread.current.name = 'cleaner'
        loop do
          sleep(60) unless strength == 1 # which will only happen in tests
          VerboseThread.new(@log).run do
            clean(host, port, strength, threads)
          end
        end
      end
      @log.info("Farm started with #{@threads.count} threads at #{host}:#{port}, strength is #{strength}")
      return unless block_given?
      begin
        yield
      ensure
        stop
      end
    end

    def stop
      @log.info("Terminating the farm with #{@threads.count} threads...")
      start = Time.now
      @threads.each do |t|
        tstart = Time.now
        t.exit
        @log.info("Thread #{t.name} terminated in #{(Time.now - tstart).round(2)}s")
      end
      @log.info("Farm stopped in #{(Time.now - start).round(2)}s")
    end

    private

    def clean(host, port, strength, threads)
      @mutex.synchronize do
        before = @best.map(&:value).max
        @best = @best.reject(&:expired?).sort_by(&:value).reverse
        @best = @best.take(threads) unless threads.zero?
        if @scores.length < threads || @best.count < threads
          zero = Score.new(Time.now, host, port, @invoice, strength: strength)
          @scores << zero
          @best << zero
        end
        after = @best.map(&:value).max
        @log.debug("#{Thread.current.name}: best score is #{@best[0]}") if before != after && !after.zero?
      end
    end

    def cycle(host, port, strength, threads)
      clean(host, port, strength, threads)
      s = @scores.pop
      return unless s.valid?
      return unless s.host == host
      return unless s.port == port
      return unless s.strength >= strength
      n = s.next
      @mutex.synchronize do
        save(n)
        @best << n
      end
      clean(host, port, strength, threads)
      @scores << n
    end

    def save(score)
      AtomicFile.new(@cache).write((history + [score]).map(&:to_s).uniq.join("\n"))
    end

    def history(max = 16)
      if File.exist?(@cache)
        AtomicFile.new(@cache).read
          .split(/\n/)
          .map { |t| Score.parse(t) }
          .select(&:valid?)
          .sort_by(&:value)
          .reverse
          .take(max)
      else
        []
      end
    end
  end
end
