# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative '../test__helper'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/commands/create'

# CREATE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestCreate < Zold::Test
  def test_creates_wallet
    Dir.mktmpdir do |dir|
      wallets = Zold::Wallets.new(dir)
      id = Zold::Create.new(wallets: wallets, remotes: nil, log: fake_log).run(
        ['create', '--public-key=fixtures/id_rsa.pub', '--skip-test']
      )
      wallets.acq(id) do |wallet|
        assert_predicate(wallet.balance, :zero?)
        assert_path_exists(
          File.join(dir, "#{wallet.id}#{Zold::Wallet::EXT}"),
          "Wallet file not found: #{wallet.id}#{Zold::Wallet::EXT}"
        )
      end
    end
  end
end
