require 'semantic'
require 'zold/version'
require 'minitest/autorun'

class TestVersion < Minitest::Test
  def test_has_version
    assert Semantic::Version.new(Zold::VERSION)
  end

  def test_has_protocol
    assert Semantic::Version.new(Zold::PROTOCOL)
  end
end
