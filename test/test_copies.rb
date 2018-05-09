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
require_relative '../lib/zold/copies.rb'

# Copies test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestCopies < Minitest::Test
  def test_adds_copies
    Dir.mktmpdir 'test' do |dir|
      copies = Zold::Copies.new(File.join(dir, 'my/a/copies'))
      copies.add('hello 1', '192.168.0.1', 80, 1)
      copies.add('hello 2', '192.168.0.2', 80, 3)
      copies.add('hello 2', '192.168.0.3', 80, 7)
      copies.add('hello 1', '192.168.0.4', 80, 10)
      assert(copies.all.count == 2, "#{copies.all.count} is not equal to 2")
      assert(copies.all.find { |c| c[:name] == '1' }[:score] == 11)
    end
  end

  def test_overwrites_host
    Dir.mktmpdir 'test' do |dir|
      copies = Zold::Copies.new(File.join(dir, 'my/a/copies'))
      host = 'b1.zold.io'
      copies.add('z1', host, 80, 5)
      copies.add('z1', host, 80, 6)
      copies.add('z1', host, 80, 7)
      assert(copies.all.count == 1, "#{copies.all.count} is not equal to 1")
      assert(copies.all[0][:score] == 7, "#{copies.all[0][:score]} is not 7")
    end
  end

  def test_cleans_copies
    Dir.mktmpdir 'test' do |dir|
      copies = Zold::Copies.new(dir)
      copies.add('h1', 'zold.io', 50, 80, Time.now - 25)
      copies.add('h1', 'zold.io', 33, 80, Time.now - 26)
      assert(File.exist?(File.join(dir, '1')))
      copies.clean
      assert(copies.all.empty?, "#{copies.all.count} is not empty")
      assert(!File.exist?(File.join(dir, '1')))
    end
  end
end
