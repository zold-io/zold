# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'
require 'tempfile'
require 'time'

# The entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
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
      raise(RuntimeError, 'Block must be given to start()') unless block_given?
      yield(self)
    end

    def to_json(*_args)
      {
        history: @history.join(', '),
        history_size: @history.count,
        speed: @speed.empty? ? 0 : (@speed.sum / @speed.count),
        pipeline: @pipeline.to_json
      }
    end

    # Returns a list of modified wallets (as Zold::Id)
    def push(id, body)
      raise(RuntimeError, 'Id can\'t be nil') if id.nil?
      raise(RuntimeError, 'Id must be of type Id') unless id.is_a?(Id)
      raise(RuntimeError, 'Body can\'t be nil') if body.nil?
      modified = @pipeline.push(id, body, @wallets, @log)
      sec = (Time.now - Time.now).round(2)
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
