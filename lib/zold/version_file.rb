require 'semantic'

module Zold
  # Read and write .zoldata/version.
  class VersionFile
    def initialize(directory)
      @directory = directory
    end

    def path
      File.join(@directory, 'version')
    end

    def save(version)
      File.open(version_file_path, 'w') do |file|
        file.puts(version)
      end
    end

    def data_version
      version_string = File.read(path)
      Semantic::Version.new(version_string)
    rescue Errno::ENOENT
      # @todo #285:30min Save the version if there is no .zoldata/version
      #  present yet. This is breaking the specs, it needs some additional time.

      # File.open('.zoldata/version', 'w') do |file|
      #   file.puts(Zold::VERSION)
      # end
      false
    end
  end
end
