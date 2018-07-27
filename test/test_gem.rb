# frozen_string_literal: true

require_relative '../lib/zold/gem'
require 'webmock/minitest'
require 'minitest/autorun'

class TestGem < Minitest::Test
  def test_last_version
    gem = Zold::Gem.new
    version = (1..3).map { rand(9).to_s } .join('.')
    stub_request(:get, 'http://rubygems.org/api/v1/versions/zold/latest.json').to_return(
      status: 200,
      body: "{\"version\": \"#{version}\"}"
    )
    assert_equal(version, gem.last_version)
  end
end
