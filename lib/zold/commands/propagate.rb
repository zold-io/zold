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

require_relative '../log'
require_relative '../wallet'
require_relative '../wallets'
require_relative '../prefixes'

# PROPAGATE command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # PROPAGATE pulling command
  class Propagate
    def initialize(wallets:, log: Log::Quiet.new)
      @wallets = wallets
      @log = log
    end

    # Returns list of Wallet IDs which were affected
    def run(args = [])
      opts = Slop.parse(args, help: true) do |o|
        o.banner = "Usage: zold propagate [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise 'At least one wallet ID is required' if opts.arguments.empty?
      modified = []
      opts.arguments.each do |id|
        modified += propagate(@wallets.find(id), opts)
      end
      modified
    end

    # Returns list of Wallet IDs which were affected
    def propagate(wallet, _)
      me = wallet.id
      modified = []
      wallet.txns.select { |t| t.amount.negative? }.each do |t|
        target = @wallets.find(t.bnf)
        unless target.exists?
          @log.debug("#{t.amount * -1} to #{t.bnf}: wallet is absent")
          next
        end
        next if target.has?(t.id, me)
        unless Prefixes.new(target).valid?(t.prefix)
          @log.info("#{t.amount * -1} to #{t.bnf}: wrong prefix")
          next
        end
        target.add(t.inverse(me))
        @log.info("#{t.amount * -1} arrived to #{t.bnf}: #{t.details}")
        modified << t.id
      end
      modified.uniq!
      @log.debug("Wallet #{me} propagated successfully, #{modified.count} wallets affected")
      modified
    end
  end
end
