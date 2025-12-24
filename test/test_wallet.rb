# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require_relative 'test__helper'
require_relative 'fake_home'
require_relative '../lib/zold/key'
require_relative '../lib/zold/age'
require_relative '../lib/zold/id'
require_relative '../lib/zold/wallet'
require_relative '../lib/zold/txn'
require_relative '../lib/zold/thread_pool'
require_relative '../lib/zold/amount'
require_relative '../lib/zold/commands/pay'

# Wallet test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class TestWallet < Zold::Test
  def test_reads_empty_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      assert_empty(wallet.txns)
      assert_equal(Zold::Amount::ZERO, wallet.balance)
    end
  end

  def test_generates_memo
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      refute_nil(wallet.mnemo)
    end
  end

  def test_reads_large_wallet
    key = Zold::Key.new(file: 'fixtures/id_rsa')
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet(Zold::Id.new('448b451bc62e8e16'))
      FileUtils.cp('fixtures/448b451bc62e8e16.z', wallet.path)
      start = Time.now
      wallet.txns
      wallet.sub(Zold::Amount.new(zld: 39.99), "NOPREFIX@#{Zold::Id.new}", key)
      time = Time.now - start
      assert_operator(time, :<, 0.5, "Too slow: #{Zold::Age.new(start)} seconds")
    end
  end

  def test_adds_transaction
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      assert_equal(
        wallet.balance, amount * -3,
        "#{wallet.balance} is not equal to #{amount * -3}"
      )
    end
  end

  def test_adds_similar_transaction
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      id = Zold::Id.new
      wallet.sub(amount, "NOPREFIX@#{id}", key)
      wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      assert_raises do
        wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      end
      assert_raises do
        wallet.add(Zold::Txn.new(1, Time.now, amount * -1, 'NOPREFIX', id, '-'))
      end
      assert_predicate(wallet.balance, :zero?)
    end
  end

  def test_checks_similar_transaction
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      id = Zold::Id.new
      wallet.sub(amount, "NOPREFIX@#{id}", key)
      wallet.add(Zold::Txn.new(1, Time.now, amount, 'NOPREFIX', id, '-'))
      assert(wallet.includes_negative?(1))
      assert(wallet.includes_positive?(1, id))
    end
  end

  def test_refurbishes_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 5.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      before = File.read(wallet.path)
      File.write(wallet.path, "#{File.read(wallet.path)}\n\n\n")
      wallet.refurbish
      assert_equal(amount * -2, wallet.balance)
      assert_equal(before, File.read(wallet.path))
    end
  end

  def test_refurbishes_empty_wallet
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      before = File.read(wallet.path)
      File.write(wallet.path, "#{File.read(wallet.path)}\n\n\n")
      wallet.refurbish
      assert_equal(before, File.read(wallet.path))
    end
  end

  def test_positive_transactions_go_first
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      time = Time.now
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      wallet.add(Zold::Txn.new(1, time, Zold::Amount.new(zents: 1), 'NOPREFIX', Zold::Id.new, '-'))
      wallet.sub(Zold::Amount.new(zents: 2), "NOPREFIX@#{Zold::Id.new}", key, time: time)
      wallet.add(Zold::Txn.new(2, time, Zold::Amount.new(zents: 3), 'NOPREFIX', Zold::Id.new, '-'))
      wallet.sub(Zold::Amount.new(zents: 4), "NOPREFIX@#{Zold::Id.new}", key, time: time)
      assert_equal('3, 1, -2, -4', wallet.txns.map { |t| t.amount.to_i }.join(', '))
    end
  end

  def test_validate_key_on_payment
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa-2')
      assert_raises RuntimeError do
        wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      end
    end
  end

  def test_adds_transaction_and_reads_back
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      amount = Zold::Amount.new(zld: 39.99)
      key = Zold::Key.new(file: 'fixtures/id_rsa')
      txn = wallet.sub(amount, "NOPREFIX@#{Zold::Id.new}", key)
      wallet.add(txn.inverse(Zold::Id.new))
      refute(Zold::Wallet.new(wallet.path).txns[1].sign.end_with?("\n"))
    end
  end

  def test_calculates_wallet_age_in_hours
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      hours = 100
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now - (100 * 60 * 60),
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      assert_equal(hours, wallet.age.round)
    end
  end

  def test_flushes_and_reads_again
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1,
          Time.now,
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      assert_equal(1, wallet.txns.count)
      assert_equal('test', wallet.network)
      wallet.flush
      assert_equal(1, wallet.txns.count)
      assert_equal('test', wallet.network)
    end
  end

  def test_returns_modified_time
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      assert_operator(wallet.mtime, :>, Time.now - (60 * 60))
    end
  end

  def test_returns_digest
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      assert_equal(64, wallet.digest.length)
    end
  end

  def test_raises_when_broken_format
    Dir.mktmpdir do |dir|
      file = File.join(dir, "0123456701234567#{Zold::Wallet::EXT}")
      File.write(file, 'broken head')
      assert_raises(Zold::Head::CantParse) do
        Zold::Wallet.new(file).id
      end
      assert_raises(Zold::Txns::CantParse) do
        Zold::Wallet.new(file).txns
      end
    end
  end

  def test_returns_protocol
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      assert_equal(Zold::PROTOCOL, wallet.protocol)
    end
  end

  def test_iterates_income_transactions
    FakeHome.new(log: fake_log).run do |home|
      wallet = home.create_wallet
      wallet.add(
        Zold::Txn.new(
          1, Time.now, Zold::Amount.new(zld: 39.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      wallet.add(
        Zold::Txn.new(
          2, Time.now, Zold::Amount.new(zld: 14.95),
          'NOPREFIX', Zold::Id.new, '-'
        )
      )
      sum = Zold::Amount::ZERO
      wallet.txns.each do |t|
        sum += t.amount unless t.amount.negative?
      end
      assert_equal(
        sum, Zold::Amount.new(zents: 235_965_503_242),
        "#{sum} (#{sum.to_i}) is not equal to #{Zold::Amount.new(zld: 54.94)}"
      )
    end
  end

  def test_sorts_them_always_right
    FakeHome.new(log: fake_log).run do |home|
      time = Time.now
      txns = []
      50.times do
        txns << Zold::Txn.new(
          1,
          time,
          Zold::Amount.new(zld: 1.99),
          'NOPREFIX', Zold::Id.new, '-'
        )
      end
      wallet = home.create_wallet
      empty = File.read(wallet.path)
      text = ''
      10.times do
        File.write(wallet.path, empty)
        txns.shuffle!
        txns.each { |t| wallet.add(t) }
        wallet.refurbish
        if text.empty?
          text = File.read(wallet.path)
          next
        end
        assert_equal(text, File.read(wallet.path))
      end
    end
  end

  def test_collects_memory_garbage
    skip
    require 'get_process_mem'
    start = GetProcessMem.new.bytes.to_i
    Zold::Hands.exec(20) do
      40.times do |i|
        wallet = Zold::Wallet.new('fixtures/448b451bc62e8e16.z')
        GC.start
        wallet.id
        wallet.txns.count
        fake_log.debug("Memory: #{GetProcessMem.new.bytes.to_i}") if (i % 5).zero?
      end
    end
    GC.stress = true
    diff = GetProcessMem.new.bytes.to_i - start
    GC.stress = false
    fake_log.debug("Memory diff is #{diff}")
    assert_operator(diff, :<, 20_000_000)
  end
end
