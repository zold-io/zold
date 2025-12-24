# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'tempfile'
require 'time'
require 'loog'

# The entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # The entrance
  class Entrance
    def initialize(wallets, pipeline, log: Loog::NULL)
      @wallets = wallets
      @pipeline = pipeline
      @log = log
      @history = []
      @speed = []
      @mutex = Mutex.new
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      yield(self)
    end

    def to_json
      {
        history: @history.join(', '),
        history_size: @history.count,
        speed: @speed.empty? ? 0 : (@speed.sum / @speed.count),
        pipeline: @pipeline.to_json
      }
    end

    # Returns a list of modified wallets (as Zold::Id)
    def push(id, body)
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      raise 'Body can\'t be nil' if body.nil?
      start = Time.now
      modified = @pipeline.push(id, body, @wallets, @log)
      sec = (Time.now - start).round(2)
      @mutex.synchronize do
        @history.shift if @history.length >= 16
        @speed.shift if @speed.length >= 64
        @wallets.acq(id) do |wallet|
          @history << "#{sec}/#{modified.count}/#{wallet.mnemo}"
        end
        @speed << sec
      end
      modified
    end
  end
end
