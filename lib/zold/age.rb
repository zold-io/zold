# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'time'
require 'rainbow'
require_relative 'txn'

# Age in seconds.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Age
  class Age
    def initialize(time, limit: nil)
      @time = time.nil? || time.is_a?(Time) ? time : Txn.parse_time(time)
      @limit = limit
    end

    def to_s
      return '?' if @time.nil?
      sec = Time.now - @time
      txt = text(sec)
      if !@limit.nil? && sec > @limit
        Rainbow(txt).red
      else
        txt
      end
    end

    private

    def text(sec)
      return "#{(sec * 1_000_000).round}μs" if sec < 0.001
      return "#{(sec * 1000).round}ms" if sec < 1
      return "#{sec.round(2)}s" if sec < 60
      return "#{(sec / 60).round}m" if sec < 60 * 60
      hours = (sec / 3600).round
      return "#{hours}h" if hours < 24
      days = (hours / 24).round
      return "#{days}d" if days < 14
      return "#{(days / 7).round}w" if days < 40
      return "#{(days / 30).round}mo" if days < 365
      "#{(days / 365).round}y"
    end
  end
end
