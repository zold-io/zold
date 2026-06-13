# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'tmpdir'
require 'threads'
require_relative 'test__helper'
require_relative '../lib/zold/age'
require_relative '../lib/zold/endless'
require_relative '../lib/zold/dir_items'

# DirItems test.
# Author:: Yegor Bugayenko (yegor256@gmail.com)
# Copyright:: Copyright (c) 2018-2026 Zerocracy
# License:: MIT
class TestDirItems < Zold::Test
  def test_intensive_write_in_threads
    Dir.mktmpdir do |dir|
      file = File.join(dir, 'hey.txt')
      back = Thread.start do
        Zold::Endless.new('test-diritems', log: fake_log).run do
          Zold::DirItems.new(dir).fetch
        end
      end
      Threads.new(100).assert do
        start = Time.now
        File.write(file, 'test')
        fake_log.info("Saved in #{Zold::Age.new(start)}")
        sleep 1
      end
      back.kill
    end
  end

  def test_lists_empty_dir
    Dir.mktmpdir do |dir|
      d = File.join(dir, 'path с пробелами')
      FileUtils.mkdir_p(d)
      assert_equal(0, Zold::DirItems.new(d).fetch.count)
    end
  end

  def test_lists_recursively
    Dir.mktmpdir do |dir|
      files = ['test1.txt', 'a/b/c/text', 'd/e/f/text', 'a/b/c/zz/text.1.2.3']
      files.each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      found = Zold::DirItems.new(dir).fetch
      assert_equal(files.count, found.count)
      files.each do |f|
        assert_includes(found, f, f)
      end
    end
  end

  def test_lists_non_recursively
    Dir.mktmpdir do |dir|
      files = ['1.txt', 'a/1.txt', 'a/b/1.txt', 'a/b/c/1.txt']
      files.each do |f|
        path = File.join(dir, f)
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.touch(path)
      end
      found = Zold::DirItems.new(dir).fetch(recursive: false)
      assert_equal(1, found.count)
    end
  end
end
