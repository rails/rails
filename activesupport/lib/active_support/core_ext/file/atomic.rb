# frozen_string_literal: true

require "securerandom"

class File
  # Write to a file atomically. Useful for situations where you don't
  # want other processes or threads to see half-written files.
  #
  #   File.atomic_write('important.file') do |file|
  #     file.write('hello')
  #   end
  #
  # This method needs to create a temporary file. By default it will create it
  # in the same directory as the destination file. If you don't like this
  # behavior you can provide a different directory but it must be on the
  # same physical filesystem as the file you're trying to write.
  #
  #   File.atomic_write('/data/something.important', '/data/tmp') do |file|
  #     file.write('hello')
  #   end
  def self.atomic_write(file_name, temp_dir = dirname(file_name))
    old_stat = begin
      File.stat(file_name)
    rescue SystemCallError
      nil
    end

    # Names can't be longer than 255B
    tmp_suffix = ".tmp.#{SecureRandom.hex}"
    tmp_name = ".#{basename(file_name).byteslice(0, 254 - tmp_suffix.bytesize)}#{tmp_suffix}"
    tmp_path = File.join(temp_dir, tmp_name)
    open(tmp_path, RDWR | CREAT | EXCL | SHARE_DELETE | BINARY) do |temp_file|
      temp_file.binmode

      if old_stat
        # Set correct permissions on new file
        begin
          chown(old_stat.uid, old_stat.gid, temp_file.path)
          # This operation will affect filesystem ACL's
          chmod(old_stat.mode, temp_file.path)
        rescue Errno::EPERM, Errno::EACCES
          # Changing file ownership failed, moving on.
        end
      end

      return_val = yield temp_file
    rescue => error
      temp_file.close rescue nil
      unlink(temp_file.path) rescue nil
      raise error
    else
      rename(temp_file.path, file_name)
      return_val
    end
  end
end
