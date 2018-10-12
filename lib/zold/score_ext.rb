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

require 'ffi'

# The score extension.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  module ScoreExt
    extend FFI::Library

    # Default number of cores used for score calculation
    CORES = 2

    ffi_lib "#{File.dirname(__FILE__)}/../../ext/score.so"
    attach_function :calculate_nonce_extended,
                    [:uint64, :uint64, :string, :uint8],
                    :uint64

    def self.calculate_nonce(data, strength, cores = CORES)
      reader, writer = IO.pipe
      workers = cores.times.map do |c|
        # @task #475:20min `Process#fork` is not supported by windows. This
        #  needs to be replaced.
        fork do
          reader.close
          nonce = self.calculate_nonce_extended(
            (2**64 / cores) * c,
            (2**64 / cores) * (c + 1) - 1,
            data,
            strength
          )
          writer.puts "#{nonce}" if !nonce.zero?
        end
      end
      writer.close
      nonce = reader.gets
      workers.each do |w|
        Process.kill "KILL", w
      end
      return nonce.to_i
    end
  end
end
