# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../../lib/zold/remotes'
require_relative '../../../lib/zold/commands/routines/reconnect'

# Reconnect test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestReconnect < Zold::Test
  def test_reconnects
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes.csv'))
      remotes.clean
      remotes.add('localhost', 4096)
      stub_request(:get, 'http://localhost:4096/remotes').to_return(status: 404)
      opts = { 'never-reboot' => true, 'routine-immediately' => true }
      routine = Zold::Routines::Reconnect.new(opts, remotes, log: fake_log)
      routine.exec
    end
  end
end
