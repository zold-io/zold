# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'threads'
require_relative '../fake_home'
require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/async_entrance'
require_relative 'fake_entrance'

# AsyncEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestAsyncEntrance < Zold::Test
  def test_renders_json
    FakeHome.new(log: fake_log).run do |home|
      Zold::AsyncEntrance.new(FakeEntrance.new, home.dir, log: fake_log).start do |e|
        assert_equal(0, e.to_json[:queue])
      end
    end
  end

  def test_sends_through_once
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      basic = CountingEntrance.new
      Zold::AsyncEntrance.new(basic, File.join(home.dir, 'a/b/c'), log: fake_log).start do |e|
        e.push(wallet.id, File.read(wallet.path))
        assert_equal_wait(1) { basic.count }
      end
    end
  end

  def test_sends_through
    FakeHome.new(log: fake_log).run do |home|
      basic = CountingEntrance.new
      Zold::AsyncEntrance.new(basic, File.join(home.dir, 'a/b/c'), log: fake_log, queue_limit: 1000).start do |e|
        Threads.new(20).assert do
          wallet = home.create_wallet
          amount = Zold::Amount.new(zld: 39.99)
          key = Zold::Key.new(file: 'fixtures/id_rsa')
          wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
          5.times { e.push(wallet.id, File.read(wallet.path)) }
        end
        assert_equal_wait(true) { basic.count >= 20 }
      end
    end
  end

  def test_handles_broken_entrance_gracefully
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      id = wallet.id
      body = File.read(wallet.path)
      Zold::AsyncEntrance.new(BrokenEntrance.new, home.dir, log: fake_log).start do |e|
        e.push(id, body)
      end
    end
  end

  class CountingEntrance < FakeEntrance
    attr_reader :count

    def initialize
      super
      @count = 0
    end

    def push(_, _)
      @count += 1
    end
  end

  class BrokenEntrance < FakeEntrance
    def push(_, _)
      raise 'It intentionally crashes'
    end
  end
end
