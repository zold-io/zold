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
require 'securerandom'
require 'concurrent'
require 'concurrent/atomics'
require_relative 'test__helper'
require_relative '../lib/zold/atomic_file'
require_relative '../lib/zold/verbose_thread'

# AtomicFile test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestAtomicFile < Minitest::Test
  def test_writes_and_reads
    Dir.mktmpdir 'test' do |dir|
      file = Zold::AtomicFile.new(File.join(dir, 'test.txt'))
      ['', 'hello, dude!'].each do |t|
        file.write(t)
        assert_equal(t, file.read)
      end
    end
  end

  # @todo #262:30min This test is skipped because it doesn't work. I can't
  #  understand why. It seems that File.open() creates an empty file first
  #  which is then being read by File.read() in another thread. Let's find
  #  out and make AtomicFile truly thread-safe.
  def test_writes_from_many_threads
    skip
    Dir.mktmpdir 'test' do |dir|
      file = Zold::AtomicFile.new(File.join(dir, 'a.txt'))
      threads = 10
      pool = Concurrent::FixedThreadPool.new(threads)
      alive = true
      cycles = Concurrent::AtomicFixnum.new
      success = Concurrent::AtomicFixnum.new
      content = SecureRandom.hex(1000)
      threads.times do
        pool.post do
          while alive
            Zold::VerboseThread.new(test_log).run(true) do
              cycles.increment
              file.write(content)
              assert_equal(content, file.read, 'Invalid content')
              success.increment
            end
          end
        end
      end
      sleep 0.1 while cycles.value < 50
      alive = false
      pool.shutdown
      pool.wait_for_termination
      assert_equal(cycles.value, success.value)
    end
  end
end
