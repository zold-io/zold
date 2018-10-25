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
require_relative 'test__helper'
require_relative '../lib/zold/log'
require_relative '../lib/zold/age'
require_relative '../lib/zold/remotes'
require_relative '../lib/zold/verbose_thread'

# Remotes test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestRemotes < Minitest::Test
  class TestLogger
    attr_reader :msg
    def info(msg)
      @msg = msg
    end

    def debug(msg); end
  end

  def test_adds_remotes
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1')
      assert(1, remotes.all.count)
    end
  end

  def test_reads_broken_file
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      [
        ',0,0,0',
        'some garbage',
        '',
        "\n\n\n\n"
      ].each do |t|
        IO.write(file, t)
        remotes = Zold::Remotes.new(file: file)
        assert(remotes.all.empty?, remotes.all)
      end
    end
  end

  def test_iterates_and_fails
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      ips = (0..50)
      ips.each { |i| remotes.add("0.0.0.#{i}", 9999) }
      remotes.iterate(Zold::Log::Quiet.new) { raise 'Intended' }
      ips.each { |i| assert(1, remotes.all[i][:errors]) }
    end
  end

  def test_iterates_them_all
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'rrr.csv'))
      remotes.clean
      5.times { |i| remotes.add("0.0.0.#{i}", 8080) }
      total = 0
      remotes.iterate(test_log) { total += 1 }
      assert_equal(5, total)
    end
  end

  def test_log_msg_of_iterates_when_fail
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('0.0.0.1', 9999)
      log = TestLogger.new
      remotes.iterate(log) { raise 'Intended' }
      assert(log.msg.include?(' in '))
    end
  end

  def test_log_msg_of_iterates_when_take_too_long
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file, timeout: 1)
      remotes.add('127.0.0.1')
      log = TestLogger.new
      remotes.iterate(log) { sleep(2) }
      assert(log.msg.include?('Took too long to execute'))
    end
  end

  def test_removes_remotes
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1')
      remotes.add('LOCALHOST', 433)
      remotes.remove('localhost', 433)
      assert(1, remotes.all.count)
    end
  end

  def test_resets_remotes
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'remotes'))
      remotes.clean
      remotes.defaults
      remotes.defaults
      assert(!remotes.all.empty?)
    end
  end

  def test_modifies_score
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1', 1024)
      remotes.rescore('127.0.0.1', 1024, 15)
      remotes.all.each do |r|
        assert_equal(15, r[:score])
        assert_equal('http://127.0.0.1:1024/', r[:home].to_s)
      end
    end
  end

  def test_tolerates_invalid_requests
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      remotes = Zold::Remotes.new(file: file)
      remotes.error('127.0.0.1', 1024)
      remotes.rescore('127.0.0.1', 1024, 15)
    end
  end

  def test_modifies_from_many_threads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'a.csv'))
      remotes.clean
      host = '192.168.0.1'
      remotes.add(host)
      assert_in_threads(threads: 5) do
        remotes.error(host)
      end
      assert_equal(0, remotes.all.reject { |r| r[:host] == host }.size)
    end
  end

  def test_mtime
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      File.stub :mtime, Time.mktime(2018, 1, 1) do
        remotes = Zold::Remotes.new(file: file)
        remotes.add('127.0.0.1')
        assert_equal(Time.mktime(2018, 1, 1), remotes.mtime)
      end
    end
  end

  def test_read_mtime_from_file
    Dir.mktmpdir 'test' do |dir|
      file = File.join(dir, 'a/b/c/remotes')
      remotes = Zold::Remotes.new(file: file)
      remotes.clean
      assert_equal(File.mtime(file).to_i, remotes.mtime.to_i)
    end
  end

  def test_adds_from_many_threads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'xx.csv'))
      remotes.clean
      assert_in_threads(threads: 5) do |t|
        remotes.add('127.0.0.1', 8080 + t)
      end
      assert_equal(5, remotes.all.count)
    end
  end

  def test_quickly_ads_and_reads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-90.csv'))
      remotes.clean
      start = Time.now
      100.times { |i| remotes.add('192.168.0.1', 8080 + i) }
      assert_in_threads(threads: 4, loops: 10) do |t|
        remotes.add('127.0.0.1', 8080 + t)
        remotes.error('127.0.0.1', 8080 + t)
        remotes.all
        remotes.iterate(test_log) { remotes.all }
        remotes.remove('127.0.0.1', 8080 + t)
      end
      test_log.info("Total time: #{Zold::Age.new(start)}")
    end
  end

  def test_empty_remotes
    Time.stub :now, Time.mktime(2018, 1, 1) do
      remotes = Zold::Remotes::Empty.new
      assert_equal(Time.mktime(2018, 1, 1), remotes.mtime)
    end
  end

  def test_reads_mtime_from_empty_file
    Dir.mktmpdir do |dir|
      assert(!Zold::Remotes.new(file: File.join(dir, 'file/is/absent')).mtime.nil?)
    end
  end

  def test_reports_zold_error_header
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-90.csv'))
      remotes.clean
      remotes.add('11a-example.org', 8080)
      stub_request(:get, 'http://11a-example.org:8080/').to_return(
        status: 500,
        headers: {
          'X-Zold-Error': 'hey you'
        }
      )
      remotes.iterate(test_log) do |r|
        r.assert_code(200, r.http.get)
      end
    end
  end

  def test_manifests_correct_network_name
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-083.csv'), network: 'x13')
      remotes.clean
      remotes.add('r5-example.org', 8080)
      stub_request(:get, 'http://r5-example.org:8080/').to_return(status: 200)
      remotes.iterate(test_log) do |r|
        r.http.get
      end
      assert_requested(:get, 'http://r5-example.org:8080/', headers: { 'X-Zold-Network' => 'x13' })
    end
  end
end
