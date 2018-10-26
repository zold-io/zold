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

require 'minitest/autorun'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/node/emission'
require_relative '../../lib/zold/amount'

class EmissionTest < Minitest::Test
  def test_emission
    (1..10).each do |year|
      FakeHome.new(log: test_log).run do |home|
        wallet = home.create_wallet
        wallet.add(
          Zold::Txn.new(
            1, Time.now - 60 * 24 * 365 * year,
            Zold::Amount.new(zld: 39.99),
            'NOPREFIX', Zold::Id::ROOT, '-'
          )
        )
        test_log.info("Year: #{year}, Quota: #{(Zold::Emission.new(wallet).quota * 100).round(2)}%, \
Limit: #{Zold::Emission.new(wallet).limit}")
      end
    end
  end

  def test_emission_passes
    FakeHome.new(log: test_log).run do |home|
      wallet = home.create_wallet(Zold::Id::ROOT)
      wallet.add(
        Zold::Txn.new(
          1, Time.now - 60 * 24,
          Zold::Amount.new(zld: 10.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      Zold::Emission.new(wallet).check
    end
  end
end
