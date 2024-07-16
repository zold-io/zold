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
#
# This class is not thread-safe!
#
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Collection of local wallets
  class Wallets
    def initialize(dir)
      @dir = dir
    end

    # @todo #70:30min Let's make it smarter. Instead of returning
    #  the full path let's substract the prefix from it if it's equal
    #  to the current directory in Dir.pwd.
    def to_s
      mine = Pathname.new(File.expand_path(@dir))
      home = Pathname.new(File.expand_path(Dir.pwd))
      mine.relative_path_from(home).to_s
    end

    def path
      FileUtils.mkdir_p(@dir)
      File.expand_path(@dir)
    end

    # This wallet exists?
    def exists?(id)
      File.exist?(File.join(path, id.to_s + Wallet::EXT))
    end

    # Returns the list of their IDs (as plain text)
    def all
      DirItems.new(path).fetch(recursive: false).select do |f|
        file = File.join(@dir, f)
        basename = File.basename(f, Wallet::EXT)
        File.file?(file) &&
          !File.directory?(file) &&
          basename =~ /^[0-9a-fA-F]{16}$/ &&
          Id.new(basename).to_s == basename
      end.map { |w| Id.new(File.basename(w, Wallet::EXT)) }
    end

    def acq(id, exclusive: false)
      raise 'The flag can\'t be nil' if exclusive.nil?
      raise 'Id can\'t be nil' if id.nil?
      raise "Id must be of type Id, #{id.class.name} instead" unless id.is_a?(Id)
      yield Wallet.new(File.join(path, id.to_s + Wallet::EXT))
    end

    def count
      Zold::DirItems.new(@dir)
        .fetch(recursive: false)
        .select { |f| f.end_with?(Wallet::EXT) }
        .count
    end
  end
end
