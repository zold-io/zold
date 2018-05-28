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

require 'rainbow'
require 'net/http'
require_relative 'version'
require_relative 'score'

# HTTP page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Http page
  class Http
    # HTTP header we add to each HTTP request, in order to inform
    # the other node about the score. If the score is big enough,
    # the remote node will add us to its list of remote nodes.
    SCORE_HEADER = 'X-Zold-Score'.freeze

    # HTTP header we add, in order to inform the node about our
    # version. This is done mostly in order to let the other node
    # reboot itself, if the version is higher.
    VERSION_HEADER = 'X-Zold-Version'.freeze

    def initialize(uri, score = Score::ZERO)
      @uri = uri
      @score = score
    end

    def get
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = 5
      return http.request_get(@uri.path, headers)
    rescue StandardError => e
      return Net::HTTPServerError.new('1.1', '599', e.message)
    end

    def put(body)
      http = Net::HTTP.new(@uri.host, @uri.port)
      http.read_timeout = 60
      return http.request_put(
        @uri.path, body,
        headers.merge(
          'Content-Type': 'text/plain',
          'Content-Length': body.length.to_s
        )
      )
    rescue StandardError => e
      return Net::HTTPServerError.new('1.1', '599', e.message)
    end

    private

    def headers
      headers = {
        'User-Agent': "Zold #{VERSION}",
        'Connection': 'close'
      }
      headers[Http::VERSION_HEADER] = VERSION
      headers[Http::SCORE_HEADER] = @score.reduced(4).to_s if @score.valid? && @score.value >= 3 && !score.expired?
      headers
    end
  end
end
