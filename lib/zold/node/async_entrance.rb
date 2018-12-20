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

require 'concurrent'
require 'futex'
require 'securerandom'
require_relative '../age'
require_relative '../size'
require_relative '../id'
require_relative '../endless'
require_relative '../thread_pool'
require_relative '../dir_items'
require_relative 'soft_error'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    def initialize(entrance, dir, log: Log::NULL,
      threads: [Concurrent.processor_count, 8].max, queue_limit: 8)
      @entrance = entrance
      @dir = File.expand_path(dir)
      @log = log
      @threads = threads
      @pool = ThreadPool.new('async-entrance', log: log)
      @queue = Queue.new
      @queue_limit = queue_limit
    end

    def to_json
      @entrance.to_json.merge(
        'queue': @queue.size,
        'threads': @pool.count,
        'queue_limit': @queue_limit
      )
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      FileUtils.mkdir_p(@dir)
      DirItems.new(@dir).fetch.each do |f|
        file = File.join(@dir, f)
        if /^[0-9a-f]{16}-/.match(f)
          id = f.split('-')[0]
          @queue << { id: Id.new(id), file: file }
        else
          File.delete(file)
        end
      end
      @log.info("#{@queue.size} wallets pre-loaded into async_entrace from #{@dir}") unless @queue.size.zero?
      @entrance.start do
        (0..@threads).map do |i|
          @pool.add do
            Endless.new("async-e##{i}", log: @log).run do
              take
            end
          end
        end
        begin
          yield(self)
        ensure
          @pool.kill
        end
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      if @queue.size > @queue_limit
        raise(
          SoftError,
          "Queue is too long (#{@queue.size} wallets), can't add #{id}/#{Size.new(body.length)}, try again later"
        )
      end
      start = Time.now
      loop do
        uuid = SecureRandom.uuid
        file = File.join(@dir, "#{id}-#{uuid}")
        next if File.exist?(file)
        IO.write(file, body)
        @queue << { id: id, file: file }
        @log.debug("Added #{id}/#{Size.new(body.length)} to the queue at pos.#{@queue.size} \
in #{Age.new(start, limit: 0.05)}")
        break
      end
      [id]
    end

    private

    def take
      start = Time.now
      item = @queue.pop
      Thread.current.thread_variable_set(:wallet, item[:id].to_s)
      body = IO.read(item[:file])
      FileUtils.rm_f(item[:file])
      @entrance.push(item[:id], body)
      @log.debug("Pushed #{item[:id]}/#{Size.new(body.length)} to #{@entrance.class.name} \
in #{Age.new(start, limit: 0.1)}#{@queue.size.zero? ? '' : "(#{@queue.size} still in the queue)"}")
    end
  end
end
