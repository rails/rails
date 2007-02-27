require 'tempfile'

# Write to a file atomically.  Useful for situations where you don't
# want other processes or threads to see half-written files.
#
#  File.atomic_write("important.file") do |file|
#    file.write("hello")
#  end
#
# If your temp directory is not on the same filesystem as the file you're 
# trying to write, you can provide a different temporary directory.
# 
# File.atomic_write("/data/something.imporant", "/data/tmp") do |f|
#   file.write("hello")
# end
def File.atomic_write(file_name, temp_dir = Dir.tmpdir)
  temp_file = Tempfile.new(File.basename(file_name), temp_dir)
  yield temp_file
  temp_file.close
  File.rename(temp_file.path, file_name)
end