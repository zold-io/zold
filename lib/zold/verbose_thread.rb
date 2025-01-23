# frozen_string_literal: true

# Copyright (c) 2018-2025 Zerocracy
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

require 'backtrace'
require 'get_process_mem'
require_relative 'log'
require_relative 'size'

# Verbose thread.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Verbose thread
  class VerboseThread
    def initialize(log = Log::NULL)
      @log = log
    end

    def run(safe: false)
      Thread.current.report_on_exception = false
      yield
    rescue Errno::ENOMEM => e
      @log.error(Backtrace.new(e).to_s)
      @log.error("We are too big in memory (#{Size.new(GetProcessMem.new.bytes.to_i)}), quitting; \
this is not a normal behavior, you may want to report a bug to our GitHub repository")
      abort
    rescue StandardError => e
      @log.error(Backtrace.new(e).to_s)
      raise e unless safe
    end
  end
end
