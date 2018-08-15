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

require 'minitest/autorun'
require 'tmpdir'
require 'uri'
require 'webmock/minitest'
require_relative '../lib/zold/http'

# Http test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
class TestHttp < Minitest::Test
  def test_pings_broken_uri
    stub_request(:get, 'http://bad-host/').to_return(status: 500)
    res = Zold::Http.new(uri: 'http://bad-host/', score: nil).get
    assert_equal('500', res.code)
    assert_equal('', res.body)
  end

  def test_pings_with_exception
    stub_request(:get, 'http://exception/').to_return { raise 'Intentionally' }
    res = Zold::Http.new(uri: 'http://exception/', score: nil).get
    assert_equal('599', res.code)
    assert(res.body.include?('Intentionally'))
    assert(!res.header['nothing'])
  end

  def test_pings_live_uri
    stub_request(:get, 'http://good-host/').to_return(status: 200)
    res = Zold::Http.new(uri: 'http://good-host/', score: nil).get
    assert_equal('200', res.code)
  end
end
