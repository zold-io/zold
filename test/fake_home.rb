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
require_relative '../lib/zold/log'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/wallets'
require_relative '../lib/zold/sync_wallets'
require_relative '../lib/zold/cached_wallets'
require_relative '../lib/zold/key'
require_relative '../lib/zold/version'
require_relative '../lib/zold/remotes'

# Fake home dir.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class FakeHome
  attr_reader :dir
  def initialize(dir = __dir__, log: Zold::Log::NULL)
    @dir = dir
    @log = log
  end

  def run
    Dir.mktmpdir do |dir|
      FileUtils.copy(File.expand_path(File.join(__dir__, '../fixtures/id_rsa')), File.join(dir, 'id_rsa'))
      yield FakeHome.new(dir, log: @log)
    end
  end

  def wallets
    Zold::SyncWallets.new(Zold::CachedWallets.new(Zold::Wallets.new(@dir)), log: @log)
  end

  def create_wallet(id = Zold::Id.new, dir = @dir, txns: 0)
    target = Zold::Wallet.new(File.join(dir, id.to_s + Zold::Wallet::EXT))
    wallets.acq(id, exclusive: true) do |w|
      w.init(id, Zold::Key.new(file: File.expand_path(File.join(__dir__, '../fixtures/id_rsa.pub'))))
      IO.write(target.path, IO.read(w.path))
      txns.times do |i|
        w.add(
          Zold::Txn.new(
            1, Time.now,
            Zold::Amount.new(zld: (i + 1).to_f),
            'NOPREFIX', Zold::Id.new, '-'
          )
        )
      end
    end
    target
  end

  def create_wallet_json(id = Zold::Id.new)
    require 'zold/score'
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
