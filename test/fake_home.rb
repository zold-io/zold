# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'loog'
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
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class FakeHome
  attr_reader :dir

  def initialize(dir = __dir__, log: Loog::NULL)
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
      File.write(target.path, File.read(w.path))
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
        size: wallet.size,
        wallets: 1,
        mtime: wallet.mtime.utc.iso8601,
        digest: wallet.digest,
        balance: wallet.balance.to_i,
        body: File.read(wallet.path)
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
