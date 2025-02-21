# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'json'

# JSON page.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2025 Zerocracy
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
