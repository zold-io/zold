# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../fake_home'
require_relative '../../../lib/zold/remotes'
require_relative '../../../lib/zold/commands/routines/reconcile'

# Reconcile test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestReconcile < Zold::Test
  def test_reconciles
    FakeHome.new(log: fake_log).run do |home|
      remotes = home.remotes
      remotes.clean
      remotes.masters
      m = remotes.all[0]
      remotes.all.each_with_index { |r, idx| remotes.remove(r[:host], r[:port]) if idx.positive? }
      stub_request(:get, "http://#{m[:host]}:#{m[:port]}/wallets").to_return(status: 200, body: Zold::Id::ROOT.to_s)
      stub_request(:get, "http://#{m[:host]}:#{m[:port]}/wallet/#{Zold::Id::ROOT}").to_return(status: 404)
      opts = { 'never-reboot' => true, 'routine-immediately' => true }
      routine = Zold::Routines::Reconcile.new(
        opts, home.wallets, remotes, home.copies.root, 'some-fake-host:2096', log: fake_log
      )
      routine.exec
    end
  end
end
