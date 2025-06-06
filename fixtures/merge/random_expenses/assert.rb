# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require_relative 'asserts'
wallet = Zold::Wallet.new('0123456789abcdef.z')
assert_equal(Zold::Amount.new(zld: 388.0), wallet.balance)
