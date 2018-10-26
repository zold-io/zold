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

require_relative 'log'

# Synchronized file.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Synchronized file
  class SyncFile
    def initialize(path, timeout: 30, log: Log::Regular.new)
      @path = File.expand_path(path)
      @timeout = timeout
      @log = log
    end

    def open
      FileUtils.mkdir_p(File.dirname(@path))
      lock = @path + '.lock'
      res = File.open(lock, File::RDWR | File::CREAT) do |f|
        start = Time.now
        acq = nil
        cycles = 0
        loop do
          break if f.flock(File::LOCK_EX | File::LOCK_NB)
          sleep 0.001
          cycles += 1
          delay = (Time.now - start).round(2)
          if delay > @timeout
            raise "##{Process.pid}/#{Thread.current.name} can't get exclusive access to the file #{@path} \
because of the lock at #{f.path}, after #{delay}s of waiting: #{f.read}"
          end
          if (cycles % 1000).zero? && delay > 10
            @log.info("##{Process.pid}/#{Thread.current.name} still waiting for \
exclusive access to #{@path}, #{delay.round}s already: #{f.read}")
          end
        end
        acq = Time.now
        @log.debug("File locked in #{Age.new(start)}: #{@path}")
        f.write("##{Process.pid}/#{Thread.current.name}")
        r = yield @path
        @log.debug("File unlocked in #{Age.new(acq)}: #{@path}")
        r
      end
      FileUtils.rm_rf(lock)
      res
    end
  end
end
