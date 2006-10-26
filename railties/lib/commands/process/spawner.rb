require 'active_support'
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
      print "Checking if something is already running on #{OPTIONS[:address]}:#{port}..."

      begin
        srv = TCPServer.new(OPTIONS[:address], port)
        srv.close
        srv = nil

        puts "NO"
        puts "Starting dispatcher on port: #{OPTIONS[:address]}:#{port}"

        FileUtils.mkdir_p(OPTIONS[:pids])
        spawn(port)
      rescue
        puts "YES"
      end
    end
  end
end

class FcgiSpawner < Spawner
  def self.spawn(port)
    cmd = "#{OPTIONS[:spawner]} -f #{OPTIONS[:dispatcher]} -p #{port} -P #{OPTIONS[:pids]}/#{OPTIONS[:process]}.#{port}.pid"
    cmd << " -a #{OPTIONS[:address]}" if can_bind_to_custom_address?
    system(cmd)
  end

  def self.can_bind_to_custom_address?
    @@can_bind_to_custom_address ||= /^\s-a\s/.match `#{OPTIONS[:spawner]} -h`
  end
end

class MongrelSpawner < Spawner
  def self.spawn(port)
    cmd = "mongrel_rails start -d -p #{port} -P #{OPTIONS[:pids]}/#{OPTIONS[:process]}.#{port}.pid -e #{OPTIONS[:environment]}"
    cmd << "-a #{OPTIONS[:address]}" if can_bind_to_custom_address?
    system(cmd)
  end

  def self.can_bind_to_custom_address?
    true
  end
end


begin
  require_library_or_gem 'fcgi'
rescue Exception
  # FCGI not available
end

begin
  require_library_or_gem 'mongrel'
rescue Exception
  # Mongrel not available
end

server = case ARGV.first
  when "fcgi", "mongrel"
    ARGV.shift
  else
    if defined?(Mongrel)
      "mongrel"
    elsif RUBY_PLATFORM !~ /mswin/ && !silence_stderr { `spawn-fcgi -version` }.blank? && defined?(FCGI)
      "fcgi"
    end
end

case server
  when "fcgi"
    puts "=> Starting FCGI dispatchers"
    spawner_class = FcgiSpawner
  when "mongrel"
    puts "=> Starting mongrel dispatchers"
    spawner_class = MongrelSpawner
  else
    puts "Neither FCGI (spawn-fcgi) nor Mongrel was installed and available!"
    exit(0)
end



OPTIONS = {
  :environment => "production",
  :spawner     => '/usr/bin/env spawn-fcgi',
  :dispatcher  => File.expand_path(RAILS_ROOT + '/public/dispatch.fcgi'),
  :pids        => File.expand_path(RAILS_ROOT + "/tmp/pids"),
  :process     => "dispatch",
  :port        => 8000,
  :address     => '0.0.0.0',
  :instances   => 3,
  :repeat      => nil
}

ARGV.options do |opts|
  opts.banner = "Usage: spawner [platform] [options]"

  opts.separator ""

  opts.on <<-EOF
  Description:
    The spawner is a wrapper for spawn-fcgi and mongrel that makes it
    easier to start multiple processes running the Rails dispatcher. The
    spawn-fcgi command is included with the lighttpd web server, but can
    be used with both Apache and lighttpd (and any other web server
    supporting externally managed FCGI processes). Mongrel automatically
    ships with with mongrel_rails for starting dispatchers.

    The first choice you need to make is whether to spawn the Rails
    dispatchers as FCGI or Mongrel. By default, this spawner will prefer
    Mongrel, so if that's installed, and no platform choice is made,
    Mongrel is used.

    Then decide a starting port (default is 8000) and the number of FCGI
    process instances you'd like to run. So if you pick 9100 and 3
    instances, you'll start processes on 9100, 9101, and 9102.

    By setting the repeat option, you get a protection loop, which will
    attempt to restart any FCGI processes that might have been exited or
    outright crashed.

    You can select bind address for started processes. By default these
    listen on every interface. For single machine installations you would
    probably want to use 127.0.0.1, hiding them form the outside world.

     Examples:
       spawner               # starts instances on 8000, 8001, and 8002
                             # using Mongrel if available.
       spawner fcgi          # starts instances on 8000, 8001, and 8002
                             # using FCGI.
       spawner mongrel -i 5  # starts instances on 8000, 8001, 8002,
                             # 8003, and 8004 using Mongrel.
       spawner -p 9100 -i 10 # starts 10 instances counting from 9100 to
                             # 9109 using Mongrel if available.
       spawner -p 9100 -r 5  # starts 3 instances counting from 9100 to
                             # 9102 and attempts start them every 5
                             # seconds.
       spawner -a 127.0.0.1  # starts 3 instances binding to localhost
  EOF

  opts.on("  Options:")

  opts.on("-p", "--port=number",      Integer, "Starting port number (default: #{OPTIONS[:port]})")                { |OPTIONS[:port]| }
  if spawner_class.can_bind_to_custom_address?
    opts.on("-a", "--address=ip",     String,  "Bind to IP address (default: #{OPTIONS[:address]})")                { |OPTIONS[:address]| }
  end
  opts.on("-p", "--port=number",      Integer, "Starting port number (default: #{OPTIONS[:port]})")                { |v| OPTIONS[:port] = v }
  opts.on("-i", "--instances=number", Integer, "Number of instances (default: #{OPTIONS[:instances]})")            { |v| OPTIONS[:instances] = v }
  opts.on("-r", "--repeat=seconds",   Integer, "Repeat spawn attempts every n seconds (default: off)")             { |v| OPTIONS[:repeat] = v }
  opts.on("-e", "--environment=name", String,  "test|development|production (default: #{OPTIONS[:environment]})")  { |v| OPTIONS[:environment] = v }
  opts.on("-n", "--process=name",     String,  "default: #{OPTIONS[:process]}")                                    { |v| OPTIONS[:process] = v }
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
  spawner_class.record_pid

  loop do
    spawner_class.spawn_all
    sleep(OPTIONS[:repeat])
  end
else
  spawner_class.spawn_all
end
