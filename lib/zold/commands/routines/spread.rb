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

require_relative '../../log'
require_relative '../../id'
require_relative '../push'

# Spread random wallets to the network.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Routines module
  module Routines
    # Spread them
    class Spread
      def initialize(opts, wallets, remotes, log: Log::NULL)
        @opts = opts
        @wallets = wallets
        @remotes = remotes
        @log = log
      end

      def exec(_ = 0)
        return if @remotes.all.empty?
        if @opts['routine-immediately']
          @log.info('Spreading the wallets immediately, because of --routine-immediately')
        else
          sleep(60)
        end
        ids = @wallets.all.sample(10)
        Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
          ['push', "--network=#{@opts['network']}"] + ids.map(&:to_s)
        )
        if ids.empty?
          @log.info("Spread didn't push any wallets, we are empty")
        else
          @log.info("Spread #{ids.count} random wallets out of #{@wallets.all.count}: #{ids.join(', ')}")
        end
      end
    end
  end
end
