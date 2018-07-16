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

require 'rainbow'
require 'uri'
require 'net/http'
require_relative 'backtrace'
require_relative 'version'
require_relative 'score'
require_relative 'type'

# HTTP page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018 Yegor Bugayenko
# License:: MIT
module Zold
  # Http page
  class Http < Dry::Struct
    # HTTP header we add to each HTTP request, in order to inform
    # the other node about the score. If the score is big enough,
    # the remote node will add us to its list of remote nodes.
    SCORE_HEADER = 'X-Zold-Score'

    # HTTP header we add, in order to inform the node about our
    # version. This is done mostly in order to let the other node
    # reboot itself, if the version is higher.
    VERSION_HEADER = 'X-Zold-Version'

    # HTTP header we add, in order to inform the node about our
    # network. This is done in order to isolate test networks from
    # production one.
    NETWORK_HEADER = 'X-Zold-Network'

    # HTTP header we add, in order to inform the node about our
    # protocol.
    PROTOCOL_HEADER = 'X-Zold-Protocol'

    # @todo #98:30m/DEV The following two statements are seen as issues by rubocop
    #  raising a Lint/AmbiguousBlockAssociation offense. It is somthing
    #  that could be solved by changing the TargetRubyVersion in .rubocop.yml
    #  that is already taken care of in another issue. I am leaving a todo
    #  to check that rubocop doesn't complain anymore, otherwise find another
    #  solution
    attribute :uri, (Types::Class.constructor do |value|
      value.is_a?(URI) ? value : URI(value)
    end)
    attribute :score, (Types::Class.constructor do |value|
      value.nil? ? Score::ZERO : value
    end)
    attribute :network, Types::Strict::String.optional.default('test')

    def get
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 8
      http.open_timeout = 4
      path = uri.path
      path += '?' + uri.query if uri.query
      http.request_get(path, headers)
    rescue StandardError => e
      Error.new(e)
    end

    def put(body)
      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = 16
      http.open_timeout = 4
      path = uri.path
      path += '?' + uri.query if uri.query
      http.request_put(
        path, body,
        headers.merge(
          'Content-Type': 'text/plain',
          'Content-Length': body.length.to_s
        )
      )
    rescue StandardError => e
      Error.new(e)
    end

    private

    # The error, if connection fails
    class Error
      def initialize(ex)
        @ex = ex
      end

      def body
        Backtrace.new(@ex).to_s
      end

      def code
        '599'
      end

      def message
        @ex.message
      end
    end

    def headers
      headers = {
        'User-Agent': "Zold #{VERSION}",
        'Connection': 'close',
        'Accept-Encoding': 'gzip'
      }
      headers[Http::VERSION_HEADER] = Zold::VERSION
      headers[Http::PROTOCOL_HEADER] = Zold::PROTOCOL.to_s
      headers[Http::NETWORK_HEADER] = network
      headers[Http::SCORE_HEADER] = score.reduced(4).to_text if score.valid? && !score.expired? && score.value > 3
      headers
    end
  end
end
