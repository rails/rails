module Kernel
  # Turns the current script into a daemon process that detaches from the console.
  # It can be shut down with a TERM signal.
  def daemonize
    Process.daemon
  end
end
