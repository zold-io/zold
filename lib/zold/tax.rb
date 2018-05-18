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

require 'digest'
require_relative 'key'
require_relative 'id'
require_relative 'amount'

# Tax transaction.
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # A single tax payment
  class Tax
    # The minimum score a wallet can buy in order to pay taxes.
    MIN_SCORE = 16

    # The maximum allowed amount in one transaction.
    MAX_PAYMENT = Amount.new(zld: 1.0)

    # This is how much we charge per one transaction per hour
    # of storage. A wallet of 4096 transactions will pay
    # approximately 16ZLD per year.
    FEE_TXN_HOUR = Amount.new(zld: 16.0 / (365 * 24) / 4096)

    # The maximum debt we can tolerate at the wallet. If the debt
    # is bigger than this threshold, nodes must stop accepting PUSH.
    TRIAL = Amount.new(zld: 1.0)

    # For how many days to pay at once.
    DAYS_INCREMENT = 32

    def initialize(wallet)
      @wallet = wallet
    end

    def pay(pvt, best)
      fee = Tax::FEE * @wallet.txns.count * Tax::DAYS_INCREMENT * 24
      @wallet.sub(fee, best.invoice, pvt, "TAXES #{best.to_text}")
    end

    def debt
      txns = @wallet.txns
      scores = txns.map do |t|
        pfx, body = t.details.split(' ')
        next if pfx != 'TAXES' || body.nil?
        score = Score.parse_text(body)
        next if !score.valid? || score.value < MIN_SCORE
        next if t.amount > Tax::MAX_PAYMENT
        score
      end.reject(&:nil?).uniq(&:hash)
      paid = scores.empty? ? Amount::ZERO : scores.map(&:amount).inject(&:+) * -1
      age_hours = (Time.now - txns.sort_by(&:date)[0].date) / 60
      owned = Tax::FEE_TXN_HOUR * txns.count * age_hours
      owned - paid
    end
  end
end
