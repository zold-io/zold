# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'minitest/autorun'
require 'tmpdir'
require_relative '../test__helper'
require_relative '../../lib/zold/wallet'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/list'

# LIST test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestList < Zold::Test
  def test_lists_wallets_with_balances
    Dir.mktmpdir do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallets.acq(id) do |wallet|
        wallet.init(Zold::Id.new, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        Zold::List.new(wallets: wallets, copies: File.join(dir, 'copies'), log: fake_log).run
      end
    end
  end
end
