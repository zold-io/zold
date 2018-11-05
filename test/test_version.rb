# frozen_string_literal: true

require 'semantic'
require 'zold/version'
require 'minitest/autorun'

class TestVersion < Zold::Test
  def test_has_version
    assert Semantic::Version.new(Zold::VERSION)
  end

  def test_has_protocol
    assert Zold::PROTOCOL
  end
end
