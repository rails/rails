# frozen_string_literal: true

require "tmpdir"
require "fileutils"

module ClientBinariesHelper
  # Points PATH at a directory holding an executable stub for each given name, so
  # that command lookup is independent of what the CI image happens to install.
  def with_client_binaries(*names)
    Dir.mktmpdir do |dir|
      names.each do |name|
        path = File.join(dir, name)
        File.write(path, "")
        File.chmod(0755, path)
      end

      original_path = ENV["PATH"]
      ENV["PATH"] = dir

      begin
        yield
      ensure
        ENV["PATH"] = original_path
      end
    end
  end

  def stub_empty_client_binaries_path
    @original_client_binaries_path = ENV["PATH"]
    @client_binaries_dir = Dir.mktmpdir
    ENV["PATH"] = @client_binaries_dir
  end

  def restore_client_binaries_path
    ENV["PATH"] = @original_client_binaries_path
    FileUtils.remove_entry(@client_binaries_dir)
  end
end
