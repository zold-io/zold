# frozen_string_literal: true

require 'minitest/autorun'
require_relative './fake_home'
require_relative '../lib/zold/notify'
require_relative '../lib/zold/tax'

class TestNotify < Minitest::Test
  def test_notify_tax_debt
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      (1..17).each do |i|
        wallet.add(
          Zold::Txn.new(
            1,
            Time.now - 24 * 60 * 60 * 365 * i,
            Zold::Amount.new(zld: 19.99),
            'NOPREFIX', Zold::Id.new, '-'
          )
        )
      end
      tax = Zold::Tax.new(wallet)
      message = Zold::Notify.tax_debt(tax)
      assert_equal message.include?('(still acceptable)'), false
    end
  end

  def test_notify_no_tax_debt
    FakeHome.new.run do |home|
      wallet = home.create_wallet
      tax = Zold::Tax.new(wallet)
      message = Zold::Notify.tax_debt(tax)
      assert message.include?('(still acceptable)')
    end
  end
end
