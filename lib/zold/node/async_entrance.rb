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

require 'concurrent'
require_relative '../log'
require_relative '../verbose_thread'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    def initialize(entrance, log: Log::Quiet.new)
      raise 'Entrance can\'t be nil' if entrance.nil?
      @entrance = entrance
      raise 'Log can\'t be nil' if log.nil?
      @log = log
    end

    def start
      @entrance.start do
        @pool = Concurrent::FixedThreadPool.new(
          Concurrent.processor_count * 8,
          max_queue: Concurrent.processor_count * 32,
          fallback_policy: :abort
        )
        begin
          yield(self)
        ensure
          @log.info("Stopping async entrance, pool length is #{@pool.length}, queue length is #{@pool.queue_length}")
          @pool.shutdown
          if @pool.wait_for_termination(10)
            @log.info('Async entrance terminated peacefully')
          else
            @pool.kill
            @log.info('Async entrance was killed')
          end
        end
      end
    end

    def to_json
      @entrance.to_json.merge(
        'pool.completed_task_count': @pool.completed_task_count,
        'pool.largest_length': @pool.largest_length,
        'pool.length': @pool.length,
        'pool.queue_length': @pool.queue_length,
        'pool.running': @pool.running?
      )
    end

    def push(id, body)
      @pool.post do
        VerboseThread.new(@log).run(true) do
          @entrance.push(id, body)
        end
      end
      @log.debug("Pushed #{id}/#{body.length}b to #{@entrance.class.name}, \
pool: #{@pool.length}/#{@pool.queue_length}")
    end
  end
end
