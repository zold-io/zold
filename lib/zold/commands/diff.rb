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
require 'slop'
require 'diffy'
require 'rainbow'
require_relative 'args'
require_relative '../log'
require_relative '../patch'
require_relative '../wallet'
require_relative '../atomic_file'

# DIFF command.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # DIFF pulling command
  class Diff
    def initialize(wallets:, copies:, log: Log::Quiet.new)
      @wallets = wallets
      @copies = copies
      @log = log
    end

    def run(args = [])
      opts = Slop.parse(args, help: true, suppress_errors: true) do |o|
        o.banner = "Usage: zold diff [ID...] [options]
Available options:"
        o.bool '--help', 'Print instructions'
      end
      mine = Args.new(opts, @log).take || return
      raise 'At least one wallet ID is required' if mine.empty?
      stdout = ''
      mine.each do |id|
        stdout += diff(
          @wallets.find(Id.new(id)),
          Copies.new(File.join(@copies, id)),
          opts
        )
      end
      stdout
    end

    private

    def diff(wallet, cps, _)
      raise 'There are no remote copies, try FETCH first' if cps.all.empty?
      cps = cps.all.sort_by { |c| c[:score] }.reverse
      patch = Patch.new
      cps.each do |c|
        begin
          patch.join(Wallet.new(c[:path]))
        rescue StandardError => e
          @log.error("Can't use a copy of #{wallet.id} from #{c[:host]}:#{c[:port]}; #{e.class.name}: #{e.message}")
          @log.debug(e.backtrace.join("\n\t"))
        end
      end
      before = AtomicFile.new(wallet.path).read
      after = ''
      Tempfile.open do |f|
        patch.save(f, overwrite: true)
        after = File.read(f)
      end
      diff = Diffy::Diff.new(before, after, context: 0).to_s(:color)
      @log.info(diff)
      diff
    end
  end
end
