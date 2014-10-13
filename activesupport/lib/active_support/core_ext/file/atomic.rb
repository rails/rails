require 'fileutils'

class File
  # Write to a file atomically. Useful for situations where you don't
  # want other processes or threads to see half-written files.
  #
  #   File.atomic_write('important.file') do |file|
  #     file.write('hello')
  #   end
  #
  # If your temp directory is not on the same filesystem as the file you're
  # trying to write, you can provide a different temporary directory.
  #
  #   File.atomic_write('/data/something.important', '/data/tmp') do |file|
  #     file.write('hello')
  #   end
  def self.atomic_write(file_name, temp_dir = Dir.tmpdir)
    require 'tempfile' unless defined?(Tempfile)
    require 'fileutils' unless defined?(FileUtils)

    temp_file = Tempfile.new(basename(file_name), temp_dir)
    temp_file.binmode
    yield temp_file
    temp_file.close

    if File.exist?(file_name)
      # Get original file permissions
      old_stat = stat(file_name)
    else
      # If not possible, probe which are the default permissions in the
      # destination directory.
      old_stat = probe_stat_in(dirname(file_name))
    end

    # Overwrite original file with temp file
    FileUtils.mv(temp_file.path, file_name)

    # Set correct permissions on new file
    begin
      chown(old_stat.uid, old_stat.gid, file_name)
      # This operation will affect filesystem ACL's
      chmod(old_stat.mode, file_name)
    rescue Errno::EPERM, Errno::EACCES
      # Changing file ownership failed, moving on.
    end
  end

  # Private utility method.
  def self.probe_stat_in(dir) #:nodoc:
    basename = [
      '.permissions_check',
      Thread.current.object_id,
      Process.pid,
      rand(1000000)
    ].join('.')

    file_name = join(dir, basename)
    FileUtils.touch(file_name)
    stat(file_name)
  ensure
    FileUtils.rm_f(file_name) if file_name
  end
end
