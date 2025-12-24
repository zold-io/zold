# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../upgrades/delete_banned_wallets'
require_relative '../fake_home'

# Delete banned wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestDeleteBannedWallets < Zold::Test
  def test_delete_them
    id = Zold::Id.new(Zold::Id::BANNED[0])
    FakeHome.new(log: fake_log).run do |home|
      home.create_wallet(id)
      FileUtils.mkdir_p(File.join(home.dir, 'a/b/c'))
      File.rename(
        File.join(home.dir, "#{id}#{Zold::Wallet::EXT}"),
        File.join(home.dir, "a/b/c/#{id}#{Zold::Wallet::EXT}")
      )
      Zold::DeleteBannedWallets.new(home.dir, fake_log).exec
      assert(File.exist?(File.join(home.dir, "a/b/c/#{id}#{Zold::Wallet::EXT}-banned")))
    end
  end
end
