# frozen_string_literal: true

class File
  # Lock a file for a block so only one process can modify it at a time.
  def self.lock(file_name, &block)
    if exist?(file_name)
      open(file_name, "r+") do |f|
        f.flock LOCK_EX
        yield
      ensure
        f.flock LOCK_UN
      end
    else
      yield
    end
  end
end
