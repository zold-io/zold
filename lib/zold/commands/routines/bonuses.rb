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

require_relative '../remote'
require_relative '../pull'
require_relative '../pay'
require_relative '../push'

# Pay bonuses routine.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Routines module
  module Routines
    # Pay bonuses to random nodes
    class Bonuses
      def initialize(opts, wallets, remotes, copies, farm, log: Log::Quiet.new)
        @opts = opts
        @wallets = wallets
        @remotes = remotes
        @copies = copies
        @farm = farm
        @log = log
      end

      def exec(_ = 0)
        sleep(60 * 60) unless @opts['routine-immediately']
        raise '--private-key is required to pay bonuses' unless @opts['private-key']
        raise '--bonus-wallet is required to pay bonuses' unless @opts['bonus-wallet']
        raise '--bonus-amount is required to pay bonuses' unless @opts['bonus-amount']
        winners = Remote.new(remotes: @remotes, log: @log, farm: @farm).run(
          ['remote', 'elect', @opts['bonus-wallet'], '--private-key', @opts['private-key']]
        )
        if winners.empty?
          @log.info('No winners elected, won\'t pay any bonuses')
          return
        end
        winners.each do |score|
          Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
            ['pull', opts['bonus-wallet']]
          )
          Pay.new(wallets: @wallets, remotes: @remotes, log: @log).run(
            [
              'pay', @opts['bonus-wallet'], score.invoice, @opts['bonus-amount'],
              "Hosting bonus for #{score.host}:#{score.port} #{score.value}",
              '--private-key', @opts['private-key']
            ]
          )
          Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
            ['push', @opts['bonus-wallet']]
          )
        end
      end
    end
  end
end
