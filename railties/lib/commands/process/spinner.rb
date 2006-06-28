require 'optparse'

def daemonize #:nodoc:
  exit if fork                   # Parent exits, child continues.
  Process.setsid                 # Become session leader.
  exit if fork                   # Zap session leader. See [1].
  Dir.chdir "/"                  # Release old working directory.
  File.umask 0000                # Ensure sensible umask. Adjust as needed.
  STDIN.reopen "/dev/null"       # Free file descriptors and
  STDOUT.reopen "/dev/null", "a" # point them somewhere sensible.
  STDERR.reopen STDOUT           # STDOUT/ERR should better go to a logfile.
end

OPTIONS = {
  :interval => 5.0,
  :command  => File.expand_path(RAILS_ROOT + '/script/process/spawner'),
  :daemon   => false
}

ARGV.options do |opts|
  opts.banner = "Usage: spinner [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    The spinner is a protection loop for the spawner, which will attempt to restart any FCGI processes
    that might have been exited or outright crashed. It's a brute-force attempt that'll just try
    to run the spawner every X number of seconds, so it does pose a light load on the server.

  Examples:
    spinner # attempts to run the spawner with default settings every second with output on the terminal
    spinner -i 3 -d # only run the spawner every 3 seconds and detach from the terminal to become a daemon
    spinner -c '/path/to/app/script/process/spawner -p 9000 -i 10' -d # using custom spawner
  EOF

  opts.on("  Options:")

  opts.on("-c", "--command=path",    String) { |v| OPTIONS[:command] = v }
  opts.on("-i", "--interval=seconds", Float) { |v| OPTIONS[:interval] = v }
  opts.on("-d", "--daemon")                  { |v| OPTIONS[:daemon] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

daemonize if OPTIONS[:daemon]

trap(OPTIONS[:daemon] ? "TERM" : "INT") { exit }

loop do
  system(OPTIONS[:command])
  sleep(OPTIONS[:interval])
end