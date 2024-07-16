# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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
require 'pathname'
require_relative 'id'
require_relative 'wallet'
require_relative 'dir_items'

# The local collection of wallets.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
module Zold
  # Collection of local wallets, in a tree of directories
  class TreeWallets
    def initialize(dir)
      @dir = dir
    end

    def to_s
      path
    end

    def path
      FileUtils.mkdir_p(@dir)
      File.expand_path(@dir)
    end

    # Returns the list of their IDs (as plain text)
    def all
      DirItems.new(path).fetch.select do |f|
        next unless f.end_with?(Wallet::EXT)
        basename = File.basename(f, Wallet::EXT)
        file = File.join(path, f)
        File.file?(file) &&
          !File.directory?(file) &&
          basename =~ /^[0-9a-fA-F]{16}$/ &&
          Id.new(basename).to_s == basename
      end.map { |w| Id.new(File.basename(w, Wallet::EXT)) }
    end

    def acq(id, exclusive: false)
      raise 'The flag can\'t be nil' if exclusive.nil?
      raise 'Id can\'t be nil' if id.nil?
      raise 'Id must be of type Id' unless id.is_a?(Id)
      yield Wallet.new(
        File.join(path, (id.to_s.split('', 5).take(4) + [id.to_s]).join('/') + Wallet::EXT)
      )
    end

    def count
      `find #{@dir} -name "*.z" | wc -l`.strip.to_i
    end
  end
end
