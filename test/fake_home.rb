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

require 'tmpdir'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/key'

# Fake home dir.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class FakeHome
  attr_reader :dir
  def initialize(dir = __dir__)
    @dir = dir
  end

  def run
    Dir.mktmpdir 'test' do |dir|
      FileUtils.copy(File.join(__dir__, '../fixtures/id_rsa'), File.join(dir, 'id_rsa'))
      yield FakeHome.new(dir)
    end
  end

  def wallets
    Zold::Wallets.new(@dir)
  end

  def create_wallet(id = Zold::Id.new)
    wallet = Zold::Wallet.new(File.join(@dir, id.to_s))
    wallet.init(id, Zold::Key.new(file: File.join(__dir__, '../fixtures/id_rsa.pub')))
    wallet
  end

  def copies(wallet = create_wallet)
    Zold::Copies.new(File.join(@dir, "copies/#{wallet.id}"))
  end

  def remotes
    remotes = Zold::Remotes.new(File.join(@dir, 'secrets/remotes'))
    remotes.clean
    remotes
  end
end
