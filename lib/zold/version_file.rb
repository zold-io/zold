# frozen_string_literal: true

# Copyright (c) 2018 Yegor Bugayenko
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the 'Software'), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

require 'semantic'
require_relative 'log'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(path, log: Log::Verbose.new)
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
