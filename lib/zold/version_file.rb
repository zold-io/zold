# frozen_string_literal: true

# SPDX-FileCopyrightText: Copyright (c) 2018-2026 Zerocracy
# SPDX-License-Identifier: MIT

require 'semantic'
require 'loog'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(path, log: Loog::NULL)
      @path = path
      @log = log
    end

    def apply(script)
      version = extract_version_from_script_name(script)
      return unless ::Gem::Version.new(version) > current_version
      code = File.read(script)
      eval(code)
    end

    def extract_version_from_script_name(file_name)
      file_name.scan(/\d\.\d\.\d/).last
    end

    def current_version
      return ::Gem::Version.new('0.0.0') unless File.exist?(version_file)
      @current_version ||= ::Gem::Version.new(current_version_from_version_file)
    end

    def current_version_from_version_file
      File.read(version_file).strip
    end

    def version_file
      File.join(@path, 'version')
    end
  end
end
