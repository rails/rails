module Kernel
  # Turns the current script into a daemon process that detaches from the console.
  # It can be shut down with a TERM signal.
  def daemonize
    exit if fork                   # Parent exits, child continues.
    Process.setsid                 # Become session leader.
    exit if fork                   # Zap session leader. See [1].
    Dir.chdir "/"                  # Release old working directory.
    File.umask 0000                # Ensure sensible umask. Adjust as needed.
    STDIN.reopen "/dev/null"       # Free file descriptors and
    STDOUT.reopen "/dev/null", "a" # point them somewhere sensible.
    STDERR.reopen STDOUT           # STDOUT/ERR should better go to a logfile.
    trap("TERM") { exit }
  end
end