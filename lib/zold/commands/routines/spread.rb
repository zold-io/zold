# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'shellwords'
require_relative '../routines'
require 'loog'
require_relative '../../id'
require_relative '../../copies'
require_relative '../push'

# Spread random wallets to the network.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
# License:: MIT
class Zold::Routines::Spread
  def initialize(opts, wallets, remotes, copies, log: Loog::NULL)
    @opts = opts
    @wallets = wallets
    @remotes = remotes
    @copies = copies
    @log = log
  end

  def exec(_ = 0)
    sleep(60) unless @opts['routine-immediately']
    @wallets.all.sample(100).each do |id|
      next if Zold::Copies.new(File.join(@copies, id)).all.count < 2
      Zold::Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
        ['push', "--network=#{Shellwords.escape(@opts['network'])}", id.to_s]
      )
    end
  end
end
