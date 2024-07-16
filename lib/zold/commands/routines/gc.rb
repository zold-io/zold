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

require_relative '../routines'
require_relative '../../log'
require_relative '../remove'

# Gargage collecting. It goes through the list of all wallets and removes
# those that are older than 10 days and don't have any transactions inside.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
class Zold::Routines::Gc
  def initialize(opts, wallets, log: Log::NULL)
    @opts = opts
    @wallets = wallets
    @log = log
  end

  def exec(_ = 0)
    sleep(60) unless @opts['routine-immediately']
    cmd = Zold::Remove.new(wallets: @wallets, log: @log)
    args = ['remove']
    seen = 0
    removed = 0
    @wallets.all.each do |id|
      seen += 1
      next unless @wallets.acq(id) { |w| w.exists? && w.mtime < Time.now - @opts['gc-age'] && w.txns.empty? }
      cmd.run(args + [id.to_s])
      removed += 1
    end
    @log.info("Removed #{removed} empty+old wallets out of #{seen} total") unless removed.zero?
  end
end
