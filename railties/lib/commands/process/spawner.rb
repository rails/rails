require 'optparse'
require 'socket'

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

def spawn(port)
  print "Checking if something is already running on port #{port}..."
  begin
    srv = TCPServer.new('0.0.0.0', port)
    srv.close
    srv = nil
    print "NO\n "
    print "Starting FCGI on port: #{port}\n  "
    system("#{OPTIONS[:spawner]} -f #{OPTIONS[:dispatcher]} -p #{port}")
  rescue
    print "YES\n"
  end
end
				    
def spawn_all
  OPTIONS[:instances].times { |i| spawn(OPTIONS[:port] + i) }
end

OPTIONS = {
  :environment => "production",
  :spawner     => '/usr/bin/env spawn-fcgi',
  :dispatcher  => File.expand_path(RAILS_ROOT + '/public/dispatch.fcgi'),
  :port        => 8000,
  :instances   => 3,
  :repeat      => nil
}

ARGV.options do |opts|
  opts.banner = "Usage: spawner [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    The spawner is a wrapper for spawn-fcgi that makes it easier to start multiple FCGI
    processes running the Rails dispatcher. The spawn-fcgi command is included with the lighttpd 
    web server, but can be used with both Apache and lighttpd (and any other web server supporting
    externally managed FCGI processes).

    You decide a starting port (default is 8000) and the number of FCGI process instances you'd 
    like to run. So if you pick 9100 and 3 instances, you'll start processes on 9100, 9101, and 9102.

    By setting the repeat option, you get a protection loop, which will attempt to restart any FCGI processes
    that might have been exited or outright crashed. 

  Examples:
    spawner               # starts instances on 8000, 8001, and 8002
    spawner -p 9100 -i 10 # starts 10 instances counting from 9100 to 9109
    spawner -p 9100 -r 5  # starts 3 instances counting from 9100 to 9102 and attempts start them every 5 seconds
  EOF

  opts.on("  Options:")

  opts.on("-p", "--port=number",      Integer, "Starting port number (default: #{OPTIONS[:port]})")                { |v| OPTIONS[:port] = v }
  opts.on("-i", "--instances=number", Integer, "Number of instances (default: #{OPTIONS[:instances]})")            { |v| OPTIONS[:instances] = v }
  opts.on("-r", "--repeat=seconds",   Integer, "Repeat spawn attempts every n seconds (default: off)")             { |v| OPTIONS[:repeat] = v }
  opts.on("-e", "--environment=name", String,  "test|development|production (default: #{OPTIONS[:environment]})")  { |v| OPTIONS[:environment] = v }
  opts.on("-s", "--spawner=path",     String,  "default: #{OPTIONS[:spawner]}")                                    { |v| OPTIONS[:spawner] = v }
  opts.on("-d", "--dispatcher=path",  String,  "default: #{OPTIONS[:dispatcher]}") { |dispatcher| OPTIONS[:dispatcher] = File.expand_path(dispatcher) }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

ENV["RAILS_ENV"] = OPTIONS[:environment]

if OPTIONS[:repeat]
  daemonize
  trap("TERM") { exit }

  loop do
    spawn_all
    sleep(OPTIONS[:repeat])
  end
else
  spawn_all
end
