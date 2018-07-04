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

module Zold
  module ScoreExt
    extend FFI::Library
    # @todo 1min Windows dll is not supported yet.
    # Make sure to implemennt the correct commands
    # in the Rakefile first.
    # Affected tasks: compile, compile_test
    ffi_lib "#{__dir__}/../../../ext/build/score.so"
    attach_function :calculate_nonce_extended,
                    [:uint64, :uint64, :string, :uint8],
                    :uint64

    def self.calculate_nonce_multi_core(cores, data, strength)
      reader, writer = IO.pipe
      begin
        workers = cores.times.map do |c|
          # @todo 20min Windows process spawn.
          # The Process.fork command is to avaibale on every
          # platform. See https://ruby-doc.org/core-2.3.3/Process.html#fork-method
          fork do
            reader.close
            per_core = (2**64 / cores)
            writer.puts self.calculate_nonce_extended(
              per_core  * c,
              per_core * (c + 1) - 1, data, strength
            )
          end
        end
        writer.close
        nonce = reader.gets
      ensure
        workers.each do |w|
          begin
            Process.kill :KILL, w
            Process.waitpid w
          rescue
          end
        end
      end
      return nonce.to_i
    end
  end
end
