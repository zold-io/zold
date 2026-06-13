# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../test__helper'
require_relative '../../lib/zold/id'
require_relative '../../lib/zold/node/nospam_entrance'
require_relative 'fake_entrance'

# NoSpamEntrance test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestNoSpamEntrance < Zold::Test
  def test_ignores_spam
    Zold::NoSpamEntrance.new(RealEntrance.new, log: fake_log).start do |e|
      id = Zold::Id.new
      content = 'hello'
      refute_empty(e.push(id, content))
      assert_empty(e.push(id, content))
      assert_empty(e.push(id, content))
    end
  end

  class RealEntrance < FakeEntrance
    def push(id, _)
      [id]
    end
  end
end
