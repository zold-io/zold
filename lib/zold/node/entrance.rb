# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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

require 'tempfile'
require 'time'
require_relative '../log'

# The entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class Entrance
    def initialize(wallets, pipeline, log: Log::NULL)
      @wallets = wallets
      @pipeline = pipeline
      @log = log
      @history = []
      @speed = []
      @mutex = Mutex.new
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      yield(self)
    end

    def to_json
      {
        history: @history.join(', '),
        history_size: @history.count,
        speed: @speed.empty? ? 0 : (@speed.inject(&:+) / @speed.count),
        pipeline: @pipeline.to_json
      }
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      raise 'Body can\'t be nil' if body.nil?
      start = Time.now
      modified = @pipeline.push(id, body, @wallets, @log)
      sec = (Time.now - start).round(2)
      @mutex.synchronize do
        @history.shift if @history.length >= 16
        @speed.shift if @speed.length >= 64
        @wallets.acq(id) do |wallet|
          @history << "#{sec}/#{modified.count}/#{wallet.mnemo}"
        end
        @speed << sec
      end
      modified
    end
  end
end
