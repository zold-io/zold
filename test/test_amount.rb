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
require 'tmpdir'
require_relative '../lib/zold/amount'

# Amount test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestAmount < Minitest::Test
  def test_parses_zld
    amount = Zold::Amount.new(zld: 14.95)
    assert(
      amount.to_s.include?('14.95ZLD'),
      "#{amount} is not equal to '14.95ZLD'"
    )
  end

  def test_parses_coins
    amount = Zold::Amount.new(coins: 900_000_000)
    assert(
      amount.to_s.include?('0.21ZLD'),
      "#{amount} is not equal to '0.21ZLD'"
    )
  end

  def test_compares_amounts
    amount = Zold::Amount.new(coins: 700_000_000)
    assert(
      amount > Zold::Amount::ZERO,
      "#{amount} is not greater than zero"
    )
  end
end
