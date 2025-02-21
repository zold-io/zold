# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2025 Zerocracy
# SPDX-License-Identifier: MIT

require 'semantic'
require_relative 'log'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(path, log: Log::VERBOSE)
      @path = path
      @log = log
    end

    # @todo #285:30min Replace this stub with functionality.
    #  We need to run the script (`yield`) if the version of
    #  the script is between the saved version and the current one.
    def apply(version)
      @log.info("Version #{version} doesn't need to be applied.")
    end
  end
end
