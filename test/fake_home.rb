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

require 'tmpdir'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/sync_wallets'
require_relative '../lib/zold/key'
require_relative '../lib/zold/version'
require_relative '../lib/zold/remotes'

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
    Dir.mktmpdir do |dir|
      FileUtils.copy(File.expand_path(File.join(__dir__, '../fixtures/id_rsa')), File.join(dir, 'id_rsa'))
      yield FakeHome.new(dir)
    end
  end

  def wallets
    Zold::SyncWallets.new(Zold::Wallets.new(@dir), File.join(@dir, 'locks'))
  end

  def create_wallet(id = Zold::Id.new, dir = @dir)
    target = Zold::Wallet.new(File.join(dir, id.to_s))
    wallets.find(id) do |w|
      w.init(id, Zold::Key.new(file: File.expand_path(File.join(__dir__, '../fixtures/id_rsa.pub'))))
      IO.write(target.path, IO.read(w.path))
    end
    target
  end

  def create_wallet_json(id = Zold::Id.new)
    require_relative '../lib/zold/score'
    score = Zold::Score::ZERO
    Dir.mktmpdir 'wallets' do |external_dir|
      wallet = create_wallet(id, external_dir)
      {
        version: Zold::VERSION,
        protocol: Zold::PROTOCOL,
        id: wallet.id.to_s,
        score: score.to_h,
        wallets: 1,
        mtime: wallet.mtime.utc.iso8601,
        digest: wallet.digest,
        balance: wallet.balance.to_i,
        body: IO.read(wallet.path)
      }.to_json
    end
  end

  def copies(wallet = create_wallet)
    Zold::Copies.new(File.join(@dir, "copies/#{wallet.id}"))
  end

  def remotes
    remotes = Zold::Remotes.new(file: File.join(@dir, 'secrets/remotes'))
    remotes.clean
    remotes
  end
end
