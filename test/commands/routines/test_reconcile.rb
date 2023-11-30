# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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

require 'minitest/autorun'
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../fake_home'
require_relative '../../../lib/zold/remotes'
require_relative '../../../lib/zold/commands/routines/reconcile'

# Reconcile test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestReconcile < Zold::Test
  def test_reconciles
    FakeHome.new(log: test_log).run do |home|
      remotes = home.remotes
      remotes.clean
      remotes.masters
      m = remotes.all[0]
      remotes.all.each_with_index { |r, idx| remotes.remove(r[:host], r[:port]) if idx.positive? }
      stub_request(:get, "http://#{m[:host]}:#{m[:port]}/wallets").to_return(status: 200, body: Zold::Id::ROOT.to_s)
      stub_request(:get, "http://#{m[:host]}:#{m[:port]}/wallet/#{Zold::Id::ROOT}").to_return(status: 404)
      opts = { 'never-reboot' => true, 'routine-immediately' => true }
      routine = Zold::Routines::Reconcile.new(
        opts, home.wallets, remotes, home.copies.root, 'some-fake-host:2096', log: test_log
      )
      routine.exec
    end
  end
end
