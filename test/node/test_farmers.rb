# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'tmpdir'
require 'zold/score'
require_relative '../../lib/zold/node/farmers'
require_relative '../../lib/zold/verbose_thread'
require_relative '../test__helper'

class FarmersTest < Zold::Test
  TYPES = [Zold::Farmers::Plain, Zold::Farmers::Spawn, Zold::Farmers::Fork].freeze

  def test_calculates_next_score
    before = Zold::Score.new(host: 'some-host', port: 9999, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 3)
    TYPES.each do |farmer_class|
      after = farmer_class.new(log: fake_log).up(before)
      assert_equal(1, after.value)
      refute_predicate(after, :expired?)
      assert_equal('some-host', after.host)
      assert_equal(9999, after.port)
    end
  end

  def test_ignores_stderr_warnings_of_spawned_farmer
    Dir.mktmpdir do |dir|
      noise = File.join(dir, 'noise.rb')
      File.write(noise, "$stderr.puts('warning: already initialized constant Gem::Platform::JAVA')\n")
      before = Zold::Score.new(host: 'warned-host', port: 4096, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 2)
      opt = ENV.fetch('RUBYOPT', nil)
      ENV['RUBYOPT'] = [opt, "-r#{noise}"].compact.join(' ')
      begin
        assert_equal(
          4096, Zold::Farmers::Spawn.new(log: fake_log).up(before).port,
          'Spawned farmer must not parse stderr as a part of the score'
        )
      ensure
        ENV['RUBYOPT'] = opt
      end
    end
  end

  def test_ignores_grandchild_holding_stderr
    Dir.mktmpdir do |dir|
      holder = File.join(dir, 'holder.rb')
      File.write(holder, "Process.detach(Process.spawn('sleep', '45'))\n")
      before = Zold::Score.new(host: 'held-host', port: 8128, invoice: 'NOPREFIX4@ffffffffffffffff', strength: 2)
      opt = ENV.fetch('RUBYOPT', nil)
      ENV['RUBYOPT'] = [opt, "-r#{holder}"].compact.join(' ')
      begin
        assert_equal(
          8128, Timeout.timeout(20) { Zold::Farmers::Spawn.new(log: fake_log).up(before).port },
          'Spawned farmer must not wait for stderr to be closed by its descendants'
        )
      ensure
        ENV['RUBYOPT'] = opt
      end
    end
  end

  def test_calculates_large_score
    TYPES.each do |type|
      log = TestLogger.new(fake_log)
      thread =
        Thread.start do
          type.new(log: log).up(
            Zold::Score.new(
              host: 'a', port: 1, invoice: 'NOPREFIX4@ffffffffffffffff',
              strength: 20
            )
          )
        end
      sleep(0.1)
      thread.kill
      thread.join
    end
  end

  def test_kills_farmer
    TYPES.each do |type|
      farmer = type.new(log: fake_log)
      thread =
        Thread.start do
          Zold::VerboseThread.new(fake_log).run do
            farmer.up(Zold::Score.new(host: 'some-host', invoice: 'NOPREFIX4@ffffffffffffffff', strength: 32))
          end
        end
      sleep(1)
      thread.kill
      thread.join
    end
  end
end
