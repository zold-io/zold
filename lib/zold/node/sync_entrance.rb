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
require_relative '../log'
require_relative '../id'
require_relative '../verbose_thread'

# The sync entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance that makes sure only one thread works with a wallet
  class SyncEntrance
    def initialize(entrance, dir, timeout: 30, log: Log::NULL)
      @entrance = entrance
      @dir = dir
      @timeout = timeout
      @log = log
    end

    def to_json
      @entrance.to_json
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      if File.exist?(@dir)
        FileUtils.rm_rf(@dir)
        @log.info("Directory #{@dir} deleted")
      end
      @entrance.start do
        yield(self)
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      Futex.new(File.join(@dir, id), log: @log, timeout: 60 * 60).open do
        @entrance.push(id, body)
      end
    end
  end
end
