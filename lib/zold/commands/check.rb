# Copyright (c) 2018 Zerocracy, Inc.
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

require_relative '../log.rb'
require_relative '../id.rb'
require_relative 'pull.rb'

# CHECK command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Zerocracy, Inc.
# License:: MIT
module Zold
  # Wallet checking command
  class Check
    def initialize(wallet:, wallets:, log: Log::Quiet.new)
      @wallet = wallet
      @wallets = wallets
      @log = log
    end

    def run
      clean = true
      @wallet.income do |t|
        bnf = Pull.new(
          wallet: @wallets.find(Id.new(t[:beneficiary])),
          log: @log
        ).run
        clean = bnf.check(t[:id], t[:amount], @wallet.id)
        next if clean
        @log.error("Txn ##{t[:id]} for #{t[:amount]} is absent at #{bnf.id}")
        break
      end
      if clean
        @log.info("The #{@wallet} is clean")
      else
        @log.error("The #{@wallet} is compromised")
      end
      clean
    end
  end
end
