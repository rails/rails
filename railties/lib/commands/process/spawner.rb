require 'optparse'
require 'socket'
require 'fileutils'

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

class Spawner
  def self.record_pid(name = "#{OPTIONS[:process]}.spawner", id = Process.pid)
    FileUtils.mkdir_p(OPTIONS[:pids])
    File.open(File.expand_path(OPTIONS[:pids] + "/#{name}.pid"), "w+") { |f| f.write(id) }
  end

  def self.spawn_all
    OPTIONS[:instances].times do |i|
      port = OPTIONS[:port] + i
      print "Checking if something is already running on port #{port}..."

      begin
        srv = TCPServer.new('0.0.0.0', port)
        srv.close
        srv = nil

        print "NO\n "
        print "Starting FCGI on port: #{port}\n  "

        FileUtils.mkdir_p(OPTIONS[:pids])
        spawn(port)
      rescue
        print "YES\n"
      end
    end
  end
end

class FcgiSpawner < Spawner
  def self.spawn(port)
    system("#{OPTIONS[:spawner]} -f #{OPTIONS[:dispatcher]} -p #{port} -P #{OPTIONS[:pids]}/#{OPTIONS[:process]}.#{port}.pid")
  end
end

# TODO:
# class MongrelSpawner < Spawner
#   def self.spawn(port)
#   end
# end


OPTIONS = {
  :environment => "production",
  :spawner     => '/usr/bin/env spawn-fcgi',
  :dispatcher  => File.expand_path(RAILS_ROOT + '/public/dispatch.fcgi'),
  :pids        => File.expand_path(RAILS_ROOT + "/tmp/pids"),
  :process     => "dispatch",
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

  opts.on("-p", "--port=number",      Integer, "Starting port number (default: #{OPTIONS[:port]})")                { |OPTIONS[:port]| }
  opts.on("-i", "--instances=number", Integer, "Number of instances (default: #{OPTIONS[:instances]})")            { |OPTIONS[:instances]| }
  opts.on("-r", "--repeat=seconds",   Integer, "Repeat spawn attempts every n seconds (default: off)")             { |OPTIONS[:repeat]| }
  opts.on("-e", "--environment=name", String,  "test|development|production (default: #{OPTIONS[:environment]})")  { |OPTIONS[:environment]| }
  opts.on("-n", "--process=name",     String,  "default: #{OPTIONS[:process]}")                                    { |OPTIONS[:process]| }
  opts.on("-s", "--spawner=path",     String,  "default: #{OPTIONS[:spawner]}")                                    { |OPTIONS[:spawner]| }
  opts.on("-d", "--dispatcher=path",  String,  "default: #{OPTIONS[:dispatcher]}") { |dispatcher| OPTIONS[:dispatcher] = File.expand_path(dispatcher) }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

ENV["RAILS_ENV"] = OPTIONS[:environment]

if OPTIONS[:repeat]
  daemonize
  trap("TERM") { exit }
  FcgiSpawner.record_pid

  loop do
    FcgiSpawner.spawn_all
    sleep(OPTIONS[:repeat])
  end
else
  FcgiSpawner.spawn_all
end
