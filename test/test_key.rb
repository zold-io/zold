# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'openssl'
require_relative 'test__helper'
require_relative '../lib/zold/key'

# Key test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestKey < Zold::Test
  def test_reads_public_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    assert(key.to_pub.start_with?('MIICI'))
    assert(key.to_pub.end_with?('EAAQ=='))
    refute_includes(key.to_pub, "\n")
    assert(Zold::Key.new(text: key.to_pub).to_pub.start_with?('MIICI'))
  end

  def test_reads_private_rsa
    key = Zold::Key.new(file: 'fixtures/id_rsa')
    assert(key.to_pub.start_with?('MIIJJ'))
    assert(key.to_pub.end_with?('Sg=='))
  end

  def test_reads_public_root_rsa
    key = Zold::Key::ROOT
    assert(key.to_pub.start_with?('MIICIjANBgkqhkiG9'))
    assert(key.to_pub.end_with?('3Tp1UCAwEAAQ=='))
  end

  def test_signs_and_verifies
    pub = Zold::Key.new(file: 'fixtures/id_rsa.pub')
    pvt = Zold::Key.new(file: 'fixtures/id_rsa')
    text = 'How are you, my friend?'
    signature = pvt.sign(text)
    assert(pub.verify(signature, text))
  end

  def test_signs_and_verifies_with_random_key
    Dir.mktmpdir do |dir|
      key = OpenSSL::PKey::RSA.new(2048)
      file = File.join(dir, 'temp')
      File.write(file, key.public_key.to_s)
      pub = Zold::Key.new(file: file)
      File.write(file, key.to_s)
      pvt = Zold::Key.new(file: file)
      text = 'How are you doing, dude?'
      signature = pvt.sign(text)
      assert(pub.verify(signature, text))
    end
  end

  def test_read_public_keys
    Dir.new('fixtures/keys').grep(/\.pub$/).each do |f|
      path = "fixtures/keys/#{f}"
      pub = Zold::Key.new(file: path)
      assert_operator(pub.to_pub.length, :>, 100)
    end
  end

  def test_signs_with_real_keys
    Dir.new('fixtures/keys').grep(/[0-9]+$/).each do |f|
      pvt = Zold::Key.new(file: "fixtures/keys/#{f}")
      pub = Zold::Key.new(file: "fixtures/keys/#{f}.pub")
      text = 'How are you doing, my friend?'
      signature = pvt.sign(text)
      assert(pub.verify(signature, text))
    end
  end

  def test_parses_openssl_generated_keys
    rsa = OpenSSL::PKey::RSA.new(2048)
    Zold::Key.new(text: rsa.to_pem).to_s
    Zold::Key.new(text: rsa.public_key.to_pem).to_s
  end
end
