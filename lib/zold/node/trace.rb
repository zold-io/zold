# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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

# The web front of the node.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
module Zold
  # Log that traces everything
  class Trace
    def initialize(log, limit = 4096)
      @log = log
      @buffer = []
      @mutex = Mutex.new
      @limit = limit
    end

    def to_s
      @mutex.synchronize do
        @buffer.join("\n")
      end
    end

    def debug(msg)
      @log.debug(msg)
      append('DBG', msg) if debug?
    end

    def debug?
      @log.debug?
    end

    def info(msg)
      @log.info(msg)
      append('INF', msg) if info?
    end

    def info?
      @log.info?
    end

    def error(msg)
      @log.error(msg)
      append('ERR', msg)
    end

    private

    def append(level, msg)
      @mutex.synchronize do
        @buffer << "#{level}: #{msg}"
        @buffer.shift if @buffer.size > @limit
      end
    end
  end
end
