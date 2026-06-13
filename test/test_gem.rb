# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require_relative '../lib/zold/gem'
require 'webmock/minitest'

class TestGem < Zold::Test
  def test_last_version
    version = (1..3).map { rand(9).to_s }.join('.')
    stub_request(:get, 'https://rubygems.org/api/v1/versions/zold/latest.json').to_return(
      status: 200,
      body: "{\"version\": \"#{version}\"}"
    )
    assert_equal(version, Zold::Gem.new.last_version)
  end

  def test_last_version_live
    WebMock.allow_net_connect!
    refute_nil(Zold::Gem.new.last_version)
  end
end
