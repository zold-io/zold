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

require 'minitest/autorun'
require 'tmpdir'
require 'webmock/minitest'
require_relative '../../test__helper'
require_relative '../../../lib/zold/remotes'
require_relative '../../../lib/zold/commands/routines/reconnect.rb'

# Reconnect test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestReconnect < Minitest::Test
  def test_reconnects
    Dir.mktmpdir 'test' do |dir|
      remotes = Zold::Remotes.new(File.join(dir, 'remotes.csv'))
      remotes.clean
      stub_request(:get, 'http://b1.zold.io:80/remotes').to_return(status: 404)
      opts = { 'never-reboot' => true, 'routine-immediately' => true }
      routine = Zold::Routines::Reconnect.new(opts, remotes, log: test_log)
      routine.exec
    end
  end
end
