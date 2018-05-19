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
require_relative '../test__helper'
require_relative '../../lib/zold/node/emission'
require_relative '../../lib/zold/amount'

class EmissionTest < Minitest::Test
  def test_emission
    (1..10).each do |year|
      Dir.mktmpdir 'test' do |dir|
        id = Zold::Id.new
        wallet = Zold::Wallet.new(File.join(dir, id.to_s))
        wallet.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        wallet.add(
          Zold::Txn.new(
            1, Time.now - 24 * 365 * year,
            Zold::Amount.new(zld: 39.99),
            'NOPREFIX', Zold::Id::ROOT, '-'
          )
        )
        $log.info("Year: #{year}, Quota: #{(Zold::Emission.new(wallet).quota * 100).round(2)}%, \
Limit: #{Zold::Emission.new(wallet).limit}")
      end
    end
  end
end
