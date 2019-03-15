# frozen_string_literal: true

# Copyright (c) 2018-2019 Zerocracy, Inc.
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

require 'tempfile'
require_relative '../log'
require_relative '../remotes'
require_relative '../copies'
require_relative '../tax'
require_relative '../age'
require_relative '../commands/clean'
require_relative '../commands/merge'
require_relative '../commands/fetch'
require_relative '../commands/push'

# The entrance with journals.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The entrance that keeps a journal for each wallet
  class JournaledEntrance
    # Decorated wallets
    class Wallets < SimpleDelegator
      def initialize(wallets, log)
        @wallets = wallets
        @log = log
        super(wallets)
      end

      def acq(id, exclusive: false)
        @wallets.acq(id, exclusive: exclusive) do |wallet|
          return yield wallet unless exclusive
          before = wallet.exists? ? IO.read(wallet.path) : ''
          res = yield wallet
          after = wallet.exists? ? IO.read(wallet.path) : ''
          unless before == after
            diff = Diffy::Diff.new(before, after, context: 0).to_s
            @log.info("The wallet #{id} was modified:\n  #{diff.gsub("\n", "\n  ")}")
          end
          res
        end
      end
    end

    def initialize(entrance, wallets, dir, log, journal)
      @wallets = JournaledEntrance::Wallets.new(wallets, log)
      @entrance = entrance
      @dir = File.expand_path(dir)
      @log = log
      @journal = File.join(@dir, journal)
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      FileUtils.mkdir_p(@dir)
      yield(self)
    end

    def to_json
      @entrance.to_json.merge(
        'dir': @dir
      )
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      DirItems.new(@dir).fetch.each do |f|
        f = File.join(@dir, f)
        File.delete(f) if File.mtime(f) < Time.now - 24 * 60 * 60
      end
      @log.info("push(#{id}, #{body.length} bytes)")
      modified = @entrance.push(id, body)
      IO.write(File.join(@dir, "#{Time.now.utc.iso8601.gsub(/[^0-9]/, '-')}-#{id}"), IO.read(@journal))
      modified
    end
  end
end
