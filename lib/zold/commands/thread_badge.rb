# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

# Thread badge.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # This module should be included in each command, in order to label
  # the current Thread correctly, when the command is running. This is mostly
  # useful for debugging/testing purposes - want to be able to see what's
  # going on in the thread when it gets stuck with a Futex.
  #
  # Since all commands have exactly the same external interface and implement
  # the method "run," we catch all calls to this method and label the
  # current thread properly. We label it back when it's over.
  module ThreadBadge
    def run(args = [])
      before = Thread.current.name || ''
      Thread.current.name = "#{before}:#{self.class.name.gsub(/^Zold::/, '')}"
      begin
        super
      ensure
        Thread.current.name = before
      end
    end
  end
end
