# frozen_string_literal: true

require "tmpdir"
require "fileutils"

# Points PATH at an empty directory, so that which database client binaries
# are found doesn't depend on what is installed where the tests run.
module ClientBinariesHelper
  private
    def stub_path
      @original_path = ENV["PATH"]
      @stubbed_path = Dir.mktmpdir
      ENV["PATH"] = @stubbed_path
    end

    def restore_path
      return unless @stubbed_path

      ENV["PATH"] = @original_path
      FileUtils.rm_rf(@stubbed_path)
      @stubbed_path = nil
    end

    def put_on_path(*commands)
      commands.each do |command|
        path = File.join(@stubbed_path, command)
        File.write(path, "#!/bin/sh\n")
        File.chmod(0755, path)
      end
    end
end
