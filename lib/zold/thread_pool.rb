# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'concurrent'
require_relative 'age'
require_relative 'verbose_thread'

# Thread pool.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
module Zold
  # Thread pool
  class ThreadPool
    def initialize(title, log: Log::NULL)
      @title = title
      @log = log
      @threads = []
      @start = Time.now
    end

    # Add a new thread
    def add
      raise 'Block must be given to start()' unless block_given?
      latch = Concurrent::CountDownLatch.new(1)
      thread = Thread.start do
        Thread.current.name = @title
        VerboseThread.new(@log).run do
          latch.count_down
          yield
        end
      end
      latch.wait
      Thread.current.thread_variable_set(
        :kids,
        (Thread.current.thread_variable_get(:kids) || []) + [thread]
      )
      @threads << thread
    end

    def join(sec)
      @threads.each { |t| t.join(sec) }
    end

    # Kill them all immediately and close the pool
    def kill
      if @threads.empty?
        @log.debug("Thread pool \"#{@title}\" terminated with no threads")
        return
      end
      @log.debug("Stopping \"#{@title}\" thread pool with #{@threads.count} threads: \
#{@threads.map { |t| "#{t.name}/#{t.status}" }.join(', ')}...")
      start = Time.new
      begin
        join(0.1)
      ensure
        @threads.each do |t|
          (t.thread_variable_get(:kids) || []).each(&:kill)
          t.kill
          sleep(0.001) while t.alive? # I believe it's a bug in Ruby, this line fixes it
          Thread.current.thread_variable_set(
            :kids,
            (Thread.current.thread_variable_get(:kids) || []) - [t]
          )
        end
        @log.debug("Thread pool \"#{@title}\" terminated all threads in #{Age.new(start)}, \
it was alive for #{Age.new(@start)}: #{@threads.map { |t| "#{t.name}/#{t.status}" }.join(', ')}")
        @threads.clear
      end
    end

    # Is it empty and has no threads?
    def empty?
      @threads.empty?
    end

    # How many threads are in there
    def count
      @threads.count
    end

    # A thread with this name exists?
    def exists?(name)
      !@threads.find { |t| t.name == name }.nil?
    end

    # As a hash map
    def to_json
      @threads.map do |t|
        {
          name: t.name,
          status: t.status,
          alive: t.alive?,
          vars: t.thread_variables.map { |v| [v.to_s, t.thread_variable_get(v)] }.to_h
        }
      end
    end

    # As a text
    def to_s
      @threads.map do |t|
        [
          "#{t.name}: status=#{t.status}; alive=#{t.alive?}",
          "Vars: #{t.thread_variables.map { |v| "#{v}=\"#{t.thread_variable_get(v)}\"" }.join('; ')}",
          t.backtrace.nil? ? 'NO BACKTRACE' : "  #{t.backtrace.join("\n  ")}"
        ].join("\n")
      end
    end
  end
end
