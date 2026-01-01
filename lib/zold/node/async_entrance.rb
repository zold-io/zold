# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require 'futex'
require 'securerandom'
require_relative '../age'
require_relative '../size'
require_relative '../id'
require_relative '../endless'
require_relative '../thread_pool'
require_relative '../dir_items'
require_relative 'soft_error'

# The async entrance of the web front.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # The entrance
  class AsyncEntrance
    def initialize(entrance, dir, log: Loog::NULL,
      threads: [Concurrent.processor_count, 8].max, queue_limit: 8)
      @entrance = entrance
      @dir = File.expand_path(dir)
      @log = log
      @threads = threads
      @pool = ThreadPool.new('async-entrance', log: log)
      @queue = Queue.new
      @queue_limit = queue_limit
    end

    def to_json
      @entrance.to_json.merge(
        queue: @queue.size,
        threads: @pool.count,
        queue_limit: @queue_limit
      )
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      FileUtils.mkdir_p(@dir)
      DirItems.new(@dir).fetch.each do |f|
        file = File.join(@dir, f)
        if /^[0-9a-f]{16}-/.match?(f)
          id = f.split('-')[0]
          @queue << { id: Id.new(id), file: file }
        else
          File.delete(file)
        end
      end
      @log.info("#{@queue.size} wallets pre-loaded into async_entrance from #{@dir}") unless @queue.empty?
      @entrance.start do
        (0..@threads).map do |i|
          @pool.add do
            Endless.new("async-e##{i}", log: @log).run do
              take
            end
          end
        end
        begin
          yield(self)
        ensure
          @pool.kill
        end
      end
    end

    # Always returns an array with a single ID of the pushed wallet
    def push(id, body)
      if @queue.size > @queue_limit
        raise(
          SoftError,
          "Queue is too long (#{@queue.size} wallets), can't add #{id}/#{Size.new(body.length)}, try again later"
        )
      end
      start = Time.now
      unless exists?(id, body)
        loop do
          uuid = SecureRandom.uuid
          file = File.join(@dir, "#{id}-#{uuid}#{Wallet::EXT}")
          next if File.exist?(file)
          File.write(file, body)
          @queue << { id: id, file: file }
          @log.debug("Added #{id}/#{Size.new(body.length)} to the queue at pos.#{@queue.size} \
  in #{Age.new(start, limit: 0.05)}")
          break
        end
      end
      [id]
    end

    private

    # Returns TRUE if a file for this wallet is already in the queue.
    def exists?(id, body)
      DirItems.new(@dir).fetch.each do |f|
        next unless f.start_with?("#{id}-")
        return true if safe_read(File.join(@dir, f)) == body
      end
      false
    end

    def safe_read(file)
      File.read(file)
    rescue Errno::ENOENT
      ''
    end

    def take
      start = Time.now
      item = @queue.pop
      Thread.current.thread_variable_set(:wallet, item[:id].to_s)
      body = File.read(item[:file])
      FileUtils.rm_f(item[:file])
      @entrance.push(item[:id], body)
      @log.debug("Pushed #{item[:id]}/#{Size.new(body.length)} to #{@entrance.class.name} \
in #{Age.new(start, limit: 0.1)}#{"(#{@queue.size} still in the queue)" unless @queue.empty?}")
    end
  end
end
