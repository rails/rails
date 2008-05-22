require 'rbconfig'
require 'commands/servers/base'

unless defined?(Mongrel)
  puts "PROBLEM: Mongrel is not available on your system (or not in your path)"
  exit 1
end

require 'optparse'

OPTIONS = {
  :port        => 3000,
  :ip          => "0.0.0.0",
  :environment => (ENV['RAILS_ENV'] || "development").dup,
  :detach      => false,
  :debugger    => false
}

ARGV.clone.options do |opts|
  opts.on("-p", "--port=port", Integer, "Runs Rails on the specified port.", "Default: 3000") { |v| OPTIONS[:port] = v }
  opts.on("-b", "--binding=ip", String, "Binds Rails to the specified ip.", "Default: 0.0.0.0") { |v| OPTIONS[:ip] = v }
  opts.on("-d", "--daemon", "Make server run as a Daemon.") { OPTIONS[:detach] = true }
  opts.on("-u", "--debugger", "Enable ruby-debugging for the server.") { OPTIONS[:debugger] = true }
  opts.on("-e", "--environment=name", String,
          "Specifies the environment to run this server under (test/development/production).",
          "Default: development") { |v| OPTIONS[:environment] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

puts "=> Rails #{Rails.version} application starting on http://#{OPTIONS[:ip]}:#{OPTIONS[:port]}"

parameters = [
  "start",
  "-p", OPTIONS[:port].to_s,
  "-a", OPTIONS[:ip].to_s,
  "-e", OPTIONS[:environment],
  "-P", "#{RAILS_ROOT}/tmp/pids/mongrel.pid"
]

if OPTIONS[:detach]
  `mongrel_rails #{parameters.join(" ")} -d`
else
  ENV["RAILS_ENV"] = OPTIONS[:environment]
  RAILS_ENV.replace(OPTIONS[:environment]) if defined?(RAILS_ENV)

  start_debugger if OPTIONS[:debugger]

  puts "=> Call with -d to detach"
  puts "=> Ctrl-C to shutdown server"

  log = Pathname.new("#{File.expand_path(RAILS_ROOT)}/log/#{RAILS_ENV}.log").cleanpath
  open(log, (File::WRONLY | File::APPEND | File::CREAT)) unless File.exist? log
  tail_thread = tail(log)

  trap(:INT) { exit }

  begin
    silence_warnings { ARGV = parameters }
    load("mongrel_rails")
  ensure
    tail_thread.kill if tail_thread
    puts 'Exiting'
  end
end