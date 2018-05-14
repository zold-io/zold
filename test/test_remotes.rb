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
require_relative '../lib/zold/remotes'

# Remotes test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemotes < Minitest::Test
  def test_adds_remotes
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file)
      remotes.add('127.0.0.1')
      assert(1, remotes.all.count)
    end
  end

  def test_removes_remotes
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file)
      remotes.add('127.0.0.1')
      remotes.add('LOCALHOST', 433)
      remotes.remove('localhost', 433)
      assert(1, remotes.all.count)
    end
  end

  def test_resets_remotes
    Dir.mktmpdir 'test' do |dir|
      remotes = Zold::Remotes.new(File.join(dir, 'remotes'))
      remotes.clean
      remotes.reset
      assert(!remotes.all.empty?)
    end
  end

  def test_modifies_score
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file)
      remotes.add('127.0.0.1', 80)
      remotes.rescore('127.0.0.1', 80, 15)
      assert_equal(remotes.score('127.0.0.1', 80), 15)
    end
  end
end
