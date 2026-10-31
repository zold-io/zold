# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'loog'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(path, log: Loog::NULL)
      @path = path
      @log = log
    end

    # Run the block if the version is newer than the saved one,
    # and save the version afterwards.
    def apply(version)
      if File.exist?(@path) && ::Gem::Version.new(version) <= ::Gem::Version.new(File.read(@path).strip)
        @log.info("Version #{version} doesn't need to be applied")
        return
      end
      yield
      File.write(@path, version)
      @log.info("Version #{version} applied")
    end
  end
end
