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

require 'minitest/autorun'
require 'tmpdir'
require 'openssl'
require_relative '../../lib/zold/ext/score'

# ExtScore test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestExtScore < Minitest::Test
  def test_calculate_nonce_multi_core
    nonce = Zold::ScoreExt.calculate_nonce_multi_core(3, 'Hello World ', 2)
    hash = OpenSSL::Digest::SHA256.new("Hello World #{nonce.to_s 16}").hexdigest
    assert hash.end_with?('0' * 2)
  end

  def test_clalculate_nonce
    nonce = Zold::ScoreExt.calculate_nonce_extended(
      0, 2**64 - 1, 'Hello World ', 2
    )
    hash = OpenSSL::Digest::SHA256.new("Hello World #{nonce.to_s 16}").hexdigest
    assert hash.end_with?('0' * 2)
  end
end
