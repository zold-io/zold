# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'concurrent'
require 'concurrent/set'
require 'tempfile'
require_relative 'emission'
require_relative '../log'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'
require_relative '../commands/clean'

# The entrance that spreads what's been modified.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance
  class SpreadEntrance
    def initialize(entrance, wallets, remotes, address, log: Log::Quiet.new, ignore_score_weakeness: false)
      @entrance = entrance
      @wallets = wallets
      @remotes = remotes
      @address = address
      @log = log
      @ignore_score_weakeness = ignore_score_weakeness
    end

    def to_json
      @entrance.to_json.merge(
        'modified': @modified.size,
        'push': @push.status
      )
    end

    def start
      @entrance.start do
        @seen = Concurrent::Set.new
        @modified = Queue.new
        @push = Thread.start do
          Thread.current.abort_on_exception = true
          Thread.current.name = 'push'
          VerboseThread.new(@log).run(true) do
            loop do
              id = @modified.pop
              if @remotes.all.empty?
                @log.info("There are no remotes, won\'t spread #{id}")
              else
                Push.new(wallets: @wallets, remotes: @remotes, log: @log).run(
                  ['push', "--ignore-node=#{@address}", id.to_s] +
                  (@ignore_score_weakeness ? ['--ignore-score-weakness'] : [])
                )
              end
              @seen.delete(id)
            end
          end
        end
        begin
          yield(self)
        ensure
          @log.info('Waiting for spread entrance to finish...')
          @modified.clear
          @push.exit
          @log.info('Spread entrance finished, thread killed')
        end
      end
    end

    # This method is thread-safe
    def push(id, body)
      mods = @entrance.push(id, body)
      (mods + [id]).each do |m|
        next if @seen.include?(m)
        @seen << m
        @modified.push(m)
        @log.debug("Spread-push scheduled for #{m}, queue size is #{@modified.size}")
      end
      mods
    end
  end
end
