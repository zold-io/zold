# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'uri'
require 'zold/score'
require_relative 'json_page'
require_relative 'http'

# Class representing the Zold gem on Rubygems
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
module Zold
  # Gem
  class Gem
    def last_version
      JsonPage.new(
        Http.new(uri: 'https://rubygems.org/api/v1/versions/zold/latest.json').get.body
      ).to_hash['version']
    rescue StandardError => _e
      '0.0.0'
    end
  end
end
