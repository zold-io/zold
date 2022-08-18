# frozen_string_literal: true

# Copyright (c) 2018-2022 Zerocracy, Inc.
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

require 'fileutils'
require_relative '../lib/zold/version'
require_relative '../lib/zold/wallet'

module Zold
  # Move wallets into tree
  class MoveWalletsIntoTree
    def initialize(home, log)
      @home = home
      @log = log
    end

    def exec
      Dir.new(@home).each do |path|
        next unless path =~ /^[a-f0-9]{16}#{Wallet::EXT}$/
        f = File.join(@home, path)
        target = File.join(@home, (path.split('', 5).take(4) + [path]).join('/'))
        FileUtils.mkdir_p(File.dirname(target))
        FileUtils.mv(f, target)
        @log.info("Wallet #{path} moved to #{target}")
      end
    end
  end
end
