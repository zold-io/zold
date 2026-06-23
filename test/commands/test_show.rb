# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative '../../lib/zold/commands/show'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../test__helper'

# SHOW test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestShow < Zold::Test
  def test_checks_wallet_balance
    Dir.mktmpdir do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallets.acq(id) do |wallet|
        wallet.init(Zold::Id.new, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        assert_equal(
          Zold::Amount::ZERO,
          Zold::Show.new(wallets: wallets, copies: File.join(dir, 'c'), log: fake_log).run(['show', id.to_s])
        )
      end
    end
  end
end
