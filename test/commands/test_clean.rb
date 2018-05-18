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
require 'time'
require_relative '../test__helper'
require_relative '../../lib/zold/copies'
require_relative '../../lib/zold/commands/clean'

# CLEAN test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestClean < Minitest::Test
  def test_cleans_copies
    Dir.mktmpdir 'test' do |dir|
      id = Zold::Id.new
      copies = Zold::Copies.new(File.join(dir, "copies/#{id}"))
      copies.add('a1', 'host-1', 80, 1, Time.now - 26 * 60)
      copies.add('a2', 'host-2', 80, 2, Time.now - 26 * 60)
      Zold::Clean.new(copies: copies.root, log: $log).run(['clean', id.to_s])
      assert(copies.all.empty?)
    end
  end
end
