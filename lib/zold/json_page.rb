# frozen_string_literal: true

# Copyright (c) 2018-2024 Zerocracy
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

require 'json'

# JSON page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2024 Zerocracy
# License:: MIT
module Zold
  # JSON page
  class JsonPage
    # When can't parse the JSON page.
    class CantParse < StandardError; end

    def initialize(text, uri = '')
      raise 'JSON text can\'t be nil' if text.nil?
      raise 'JSON must be of type String' unless text.is_a?(String)
      @text = text
      @uri = uri
    end

    def to_hash
      raise CantParse, "JSON is empty, can't parse#{@uri.empty? ? '' : " at #{@uri}"}" if @text.empty?
      JSON.parse(@text)
    rescue JSON::ParserError => e
      raise CantParse, "Failed to parse JSON #{@uri.empty? ? '' : "at #{@uri}"} (#{short(e.message)}): #{short(@text)}"
    end

    private

    def short(txt)
      txt.gsub(/^.{128,}$/, '\1...').inspect
    end
  end
end
