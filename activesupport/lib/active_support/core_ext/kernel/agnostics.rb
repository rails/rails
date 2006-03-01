class Object
  # Makes backticks behave (somewhat more) similarly on all platforms.
  # On win32 `nonexistent_command` raises Errno::ENOENT; on Unix, the
  # spawned shell prints a message to stderr and sets $?.  We emulate
  # Unix on the former but not the latter.
  def `(command) #:nodoc:
    super
  rescue Errno::ENOENT => e
    STDERR.puts "#$0: #{e}"
  end
end