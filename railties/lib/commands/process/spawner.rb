require 'optparse'

def spawn(port)
  print "Starting FCGI on port: #{port}\n  "
  system("#{OPTIONS[:spawner]} -f #{OPTIONS[:dispatcher]} -p #{port}")
end

OPTIONS = {
  :environment => "production",
  :spawner     => '/usr/bin/env spawn-fcgi',
  :dispatcher  => File.expand_path(RAILS_ROOT + '/public/dispatch.fcgi'),
  :port        => 8000,
  :instances   => 3
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

  Examples:
    spawner               # starts instances on 8000, 8001, and 8002
    spawner -p 9100 -i 10 # starts 10 instances counting from 9100 to 9109
  EOF

  opts.on("  Options:")

  opts.on("-p", "--port=number", Integer, "Starting port number (default: #{OPTIONS[:port]})")                   { |OPTIONS[:port]| }
  opts.on("-i", "--instances=number", Integer, "Number of instances (default: #{OPTIONS[:instances]})")          { |OPTIONS[:instances]| }
  opts.on("-e", "--environment=name", String, "test|development|production (default: #{OPTIONS[:environment]})") { |OPTIONS[:environment]| }
  opts.on("-s", "--spawner=path",    String, "default: #{OPTIONS[:spawner]}")                                    { |OPTIONS[:spawner]| }
  opts.on("-d", "--dispatcher=path", String, "default: #{OPTIONS[:dispatcher]}") { |dispatcher| OPTIONS[:dispatcher] = File.expand_path(dispatcher) }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

ENV["RAILS_ENV"] = OPTIONS[:environment]
OPTIONS[:instances].times { |i| spawn(OPTIONS[:port] + i) }