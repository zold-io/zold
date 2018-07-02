require 'semantic'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(path)
      @path = path
    end

    def save(version)
      File.open(@path, 'w') do |file|
        file.puts(version)
      end
    end

    def apply(version)
      save(version) if yield
    end

    def version
      return unless File.exist?(path)
      version_string = File.read(path)
      Semantic::Version.new(version_string)
      # @todo #285:30min Save the version if there is no .zoldata/version
      #  present yet. This is breaking the specs, it needs some additional time.

      # File.open('.zoldata/version', 'w') do |file|
      #   file.puts(Zold::VERSION)
      # end
    end
  end
end
