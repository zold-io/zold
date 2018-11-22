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

require 'tempfile'
require 'openssl'
require_relative '../log'
require_relative '../size'
require_relative '../wallet'

# The entrance that ignores duplicates.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The safe entrance
  class NoDupEntrance
    def initialize(entrance, wallets, log: Log::NULL)
      @entrance = entrance
      @wallets = wallets
      @log = log
    end

    def start
      raise 'Block must be given to start()' unless block_given?
      @entrance.start { yield(self) }
    end

    def to_json
      @entrance.to_json
    end

    # Returns a list of modifed wallets (as Zold::Id)
    def push(id, body)
      before = @wallets.acq(id) { |w| w.exists? ? w.digest : '' }
      after = OpenSSL::Digest::SHA256.new(body).hexdigest
      if before == after
        @log.debug("Duplicate of #{id} ignored (#{Size.new(body.length)} bytes)")
        return []
      end
      @log.debug("New content for #{id} arrived (#{Size.new(body.length)} bytes)")
      @entrance.push(id, body)
    end
  end
end
