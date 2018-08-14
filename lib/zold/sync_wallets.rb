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

# Sync collection of wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Synchronized collection of wallets
  class SyncWallets
    def initialize(wallets, dir = Dir.tmpdir, timeout: 30, log: Log::Quiet.new)
      @wallets = wallets
      @dir = dir
      @log = log
      @timeout = timeout
    end

    def to_s
      @wallets.to_s
    end

    def path
      @wallets.path
    end

    def all
      @wallets.all
    end

    def find(id)
      @wallets.find(id) do |wallet|
        f = File.join(@dir, id)
        FileUtils.mkdir_p(File.dirname(f))
        File.open(f, File::RDWR | File::CREAT) do |lock|
          start = Time.now
          cycles = 0
          loop do
            break if lock.flock(File::LOCK_EX | File::LOCK_NB)
            sleep 0.1
            cycles += 1
            delay = Time.now - start
            if delay > @timeout
              raise "##{Process.pid}/#{Thread.current.name} can't get exclusive access to the wallet #{id} \
because of the lock at #{lock.path}: #{File.read(lock)}"
            end
            if (cycles % 20).zero? && delay > 10
              @log.info("##{Process.pid}/#{Thread.current.name} still waiting for \
exclusive access to #{id}, #{delay.round}s already: #{File.read(lock)}")
            end
          end
          File.write(lock, "##{Process.pid}/#{Thread.current.name}")
          yield wallet
        end
      end
    end
  end
end
