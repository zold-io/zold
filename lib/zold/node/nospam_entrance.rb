# frozen_string_literal: true

# Copyright (c) 2018-2023 Zerocracy
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
require 'zache'
require_relative '../log'
require_relative '../size'
require_relative '../age'

# The entrance that ignores something we've seen already.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # The no-spam entrance
  class NoSpamEntrance
    def initialize(entrance, period: 60 * 60, log: Log::NULL)
      @entrance = entrance
      @log = log
      @period = period
      @zache = Zache.new
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
      before = @zache.get(id.to_s, lifetime: @period) { '' }
      after = hash(id, body)
      if before == after
        @log.debug("Spam of #{id} ignored; the wallet content of #{Size.new(body.length)} \
and '#{after[0..8]}' hash has already been seen #{Age.new(@zache.mtime(id.to_s))} ago")
        return []
      end
      @zache.put(id.to_s, after)
      @entrance.push(id, body)
    end

    private

    def hash(id, body)
      OpenSSL::Digest::SHA256.new(id.to_s + ' ' + body).hexdigest
    end
  end
end
