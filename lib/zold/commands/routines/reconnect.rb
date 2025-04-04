# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'shellwords'
require_relative '../routines'
require_relative '../remote'
require_relative '../../node/farm'

# Reconnect routine.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Reconnect
  def initialize(opts, remotes, farm = Zold::Farm::Empty.new, log: Log::NULL)
    @opts = opts
    @remotes = remotes
    @farm = farm
    @log = log
  end

  def exec(step = 0)
    sleep(60) unless @opts['routine-immediately']
    cmd = Zold::Remote.new(remotes: @remotes, log: @log, farm: @farm)
    args = ['remote', "--network=#{Shellwords.escape(@opts['network'])}", '--ignore-ping']
    score = @farm.best[0]
    args << "--ignore-node=#{Shellwords.escape("#{score.host}:#{score.port}")}" if score
    cmd.run(args + ['masters']) unless @opts['routine-immediately']
    return if @opts['routine-immediately'] && @remotes.all.empty?
    cmd.run(args + ['select'])
    if (step % 10).zero?
      @log.info("It is round ##{step}, time to update the list of remotes")
      update(cmd, args)
    end
    if @remotes.all.any? { |r| r[:errors] > Zold::Remotes::TOLERANCE }
      @log.info('There are a few remote nodes with too many errors, it\'s time to update')
      update(cmd, args)
    else
      @log.debug("All #{@remotes.all.count} remote nodes are still more or less error-free, won't update")
    end
    if @remotes.all.count < Zold::Remotes::MAX_NODES / 2
      @log.info("There are just #{@remotes.all.count} remotes in the list, time to update")
      update(cmd, args)
    end
    cmd.run(args + ['trim'])
    cmd.run(args + ['select'])
    @log.info("Reconnected, there are #{@remotes.all.count} remote notes: \
#{@remotes.all.map { |r| "#{r[:host]}:#{r[:port]}/#{r[:score]}/#{r[:errors]}" }.join(', ')}")
  end

  private

  def update(cmd, args)
    cmd.run(args + ['update'] + (@opts['never-reboot'] ? [] : ['--reboot']))
  end
end
