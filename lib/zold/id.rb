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

# The ID of the wallet.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Id of the wallet
  class Id
    def initialize(id = nil)
      if id.nil?
        @id = rand(2**32..2**64 - 1)
      else
        raise "Invalid wallet ID: #{id}" unless id =~ /^[0-9a-fA-F]{16}$/
        @id = Integer("0x#{id}", 16)
      end
    end

    # The ID of the root wallet.
    ROOT = Id.new('0000000000000000')

    def eql?(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s == other.to_s
    end

    def hash
      to_s.hash
    end

    def ==(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s == other.to_s
    end

    def <=>(other)
      raise 'Can only compare with Id' unless other.is_a?(Id)
      to_s <=> other.to_s
    end

    def to_str
      to_s
    end

    def to_s
      format('%016x', @id)
    end
  end
end
