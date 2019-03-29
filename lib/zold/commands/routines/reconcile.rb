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

require 'shellwords'
require_relative '../routines'
require_relative '../../log'
require_relative '../../id'
require_relative '../../copies'
require_relative '../pull'

# R
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class Zold::Routines::Reconcile
  def initialize(opts, wallets, remotes, copies, address, log: Log::NULL)
    @opts = opts
    @wallets = wallets
    @remotes = remotes
    @copies = copies
    @address = address
    @log = log
  end

  def exec(_ = 0)
    sleep(20 * 60) unless @opts['routine-immediately']
    @remotes.iterate(@log) do |r|
      next unless r.master?
      next if r.to_mnemo == @address
      res = r.http('/wallets').get
      r.assert_code(200, res)
      missing = res.body.strip.split("\n").compact
        .select { |i| /^[a-f0-9]{16}$/.match?(i) }
        .reject { |i| @wallets.acq(Zold::Id.new(i), &:exists?) }
      missing.each { |i| pull(i) }
      if missing.empty?
        log.info("Nothing to reconcile with #{r}, we are good at #{@address}")
      else
        @log.info("Reconcile routine pulled #{missing.count} wallets from #{r}")
      end
    end
  end

  private

  def pull(id)
    Zold::Pull.new(wallets: @wallets, remotes: @remotes, copies: @copies, log: @log).run(
      ['pull', "--network=#{Shellwords.escape(@opts['network'])}", id.to_s, '--quiet-if-absent']
    )
  end
end
