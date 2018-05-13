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

require 'slop'
require_relative '../log'

# PAY command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Money sending command
  class Pay
    def initialize(wallets:, pvtkey:, log: Log::Quiet.new)
      @wallets = wallets
      @pvtkey = pvtkey
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true) do |o|
        o.banner = "Usage: zold pay FROM TO AMOUNT [options]
Available options:"
        o.bool '--force',
          'Ignore all validations',
          default: false
        o.bool '--help', 'Print instructions'
      end
      if opts.help?
        @log.info(opts.to_s)
        return
      end
      raise 'Payer wallet ID is required' if opts.arguments[0].nil?
      from = @wallets.find(Zold::Id.new(opts.arguments[0]))
      raise 'Wallet doesn\'t exist, do \'fetch\' first' unless from.exists?
      raise 'Recepient wallet ID is required' if opts.arguments[1].nil?
      to = Zold::Id.new(opts.arguments[1])
      raise 'Amount is required (in ZLD)' if opts.arguments[2].nil?
      amount = Zold::Amount.new(zld: opts.arguments[2].to_f)
      details = opts.arguments[3] ? opts.arguments[3] : '-'
      pay(from, to, amount, details, opts)
    end

    def pay(from, to, amount, details, opts)
      unless opts.force?
        raise 'Payer/beneficiary can\'t be identical' if from.id == to
        raise 'The amount can\'t be zero' if amount.zero?
        raise "The amount can't be negative: #{amount}" if amount.negative?
        if !from.root? && from.balance < @amount
          raise "There is not enough funds in #{from} to send #{amount}, \
  only #{payer.balance} left"
        end
      end
      txn = from.sub(amount, to, @pvtkey, details)
      @log.debug("#{amount} sent from #{from} to #{to}: #{details}")
      @log.info(txn[:id])
      txn
    end
  end
end
