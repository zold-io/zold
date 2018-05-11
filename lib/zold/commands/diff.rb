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

require 'tempfile'
require 'diffy'
require_relative '../log.rb'
require_relative '../patch.rb'
require_relative '../wallet.rb'

# DIFF command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # DIFF pulling command
  class Diff
    def initialize(wallet:, copies:, log: Log::Quiet.new)
      @wallet = wallet
      @copies = copies
      @log = log
    end

    def run(_ = [])
      raise 'There are no remote copies, try FETCH first' if @copies.all.empty?
      cps = @copies.all.sort_by { |c| c[:score] }.reverse
      patch = Patch.new
      patch.start(Wallet.new(cps[0][:path]))
      cps[1..-1].each do |c|
        patch.join(Wallet.new(c[:path]))
      end
      before = File.read(@wallet.path)
      after = ''
      Tempfile.open do |f|
        patch.save(f, overwrite: true)
        after = File.read(f)
      end
      diff = Diffy::Diff.new(before, after, context: 0).to_s(:color)
      @log.info("Here is the difference:\n" + diff)
      diff
    end
  end
end
