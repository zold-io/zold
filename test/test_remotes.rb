# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'webmock/minitest'
require 'threads'
require_relative 'test__helper'
require 'loog'
require_relative '../lib/zold/age'
require_relative '../lib/zold/remotes'
require_relative '../lib/zold/verbose_thread'

# Remotes test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestRemotes < Zold::Test
  def test_adds_remotes
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('127.0.0.1')
      assert(1, remotes.all.count)
    end
  end

  def test_finds_masters
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      assert(remotes.master?('b2.zold.io', 4096))
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
        File.write(file, t)
        remotes = Zold::Remotes.new(file: file)
        assert_empty(remotes.all, remotes.all)
      end
    end
  end

  def test_iterates_and_fails
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      ips = (0..50)
      ips.each { |i| remotes.add("0.0.0.#{i + 1}", 9999) }
      remotes.iterate(Loog::NULL) { raise 'Intended' }
      ips.each { |i| assert(1, remotes.all[i][:errors]) }
    end
  end

  def test_iterates_all_failures
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      5.times { |i| remotes.add("0.0.0.#{i + 1}", 9999) }
      total = 0
      remotes.iterate(Loog::NULL) do
        total += 1
        raise 'Intended'
      end
      assert_equal(5, total)
    end
  end

  def test_closes_threads_carefully
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      5.times { |i| remotes.add("0.0.0.#{i + 1}", 9999) }
      total = 0
      remotes.iterate(Loog::NULL) do
        sleep 0.25
        total += 1
      end
      assert_equal(5, total)
    end
  end

  def test_iterates_them_all_even_with_delays
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'rrr.csv'))
      remotes.clean
      5.times { |i| remotes.add("0.0.0.#{i + 1}", 8080) }
      total = 0
      remotes.iterate(fake_log) do
        sleep 0.25
        total += 1
      end
      assert_equal(5, total)
    end
  end

  def fake_log_msg_of_iterates_when_fail
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file)
      remotes.add('0.0.0.1', 9999)
      log = TestLogger.new
      remotes.iterate(log) { raise 'Intended' }
      assert(log.msgs.find { |m| m.include?(' in ') })
    end
  end

  def fake_log_msg_of_iterates_when_take_too_long
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'remotes')
      FileUtils.touch(file)
      remotes = Zold::Remotes.new(file: file, timeout: 1)
      remotes.add('127.0.0.1')
      log = TestLogger.new
      remotes.iterate(log) { sleep(2) }
      assert(log.msgs.find { |m| m.include?('Took too long to execute') })
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
      remotes.masters
      remotes.masters
      refute_empty(remotes.all)
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
      Threads.new(5).assert do
        remotes.error(host)
      end
      assert_equal(0, remotes.all.count { |r| r[:host] != host })
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
      host = '127.0.0.1'
      Threads.new(2).assert(100) do |_, r|
        port = 8080 + r
        remotes.add(host, port)
        remotes.error(host, port)
        assert(remotes.all.find { |x| x[:port] == port })
      end
      assert_equal(100, remotes.all.count)
    end
  end

  def test_quickly_ads_and_reads
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-90.csv'))
      remotes.clean
      start = Time.now
      100.times { |i| remotes.add('192.168.0.1', 8080 + i) }
      Threads.new(4).assert(10) do |t|
        remotes.add('127.0.0.1', 8080 + t)
        remotes.error('127.0.0.1', 8080 + t)
        remotes.all
        remotes.iterate(fake_log) { remotes.all }
        remotes.remove('127.0.0.1', 8080 + t)
      end
      fake_log.info("Total time: #{Zold::Age.new(start)}")
    end
  end

  def test_unerror_remote
    Dir.mktmpdir do |dir|
      remotes = Zold::Remotes.new(file: File.join(dir, 'uu-90.csv'))
      remotes.clean
      remotes.add('192.168.0.1', 8081)
      assert_equal 0, remotes.all.last[:errors]
      remotes.error('192.168.0.1', 8081)
      assert_equal 1, remotes.all.last[:errors]
      remotes.unerror('192.168.0.1', 8081)
      assert_equal 0, remotes.all.last[:errors]
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
      refute_nil(Zold::Remotes.new(file: File.join(dir, 'file/is/absent')).mtime)
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
      remotes.iterate(fake_log) do |r|
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
      remotes.iterate(fake_log) do |r|
        r.http.get
      end
      assert_requested(:get, 'http://r5-example.org:8080/', headers: { 'X-Zold-Network' => 'x13' })
    end
  end
end
