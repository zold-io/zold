# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Fake entrance.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class FakeEntrance
  def initialize
    # Nothing here
  end

  def to_json
    {}
  end

  def start
    yield self
  end

  def push(id, _)
    [id]
  end
end
