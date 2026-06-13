# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative '../test__helper'
require_relative '../../lib/zold/wallets'
require_relative '../../lib/zold/amount'
require_relative '../../lib/zold/key'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/commands/invoice'

# INVOICE test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestInvoice < Zold::Test
  def test_generates_invoice
    Dir.mktmpdir do |dir|
      id = Zold::Id.new
      wallets = Zold::Wallets.new(dir)
      wallets.acq(id) do |source|
        source.init(id, Zold::Key.new(file: 'fixtures/id_rsa.pub'))
        invoice = Zold::Invoice.new(wallets: wallets, remotes: nil, copies: nil, log: fake_log).run(
          ['invoice', id.to_s, '--length=16']
        )
        assert_equal(33, invoice.length)
      end
    end
  end
end
