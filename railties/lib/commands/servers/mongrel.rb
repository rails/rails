require 'rbconfig'
require 'commands/servers/base'

unless defined?(Mongrel)
  puts "PROBLEM: Mongrel is not available on your system (or not in your path)"
  exit 1
end

require 'initializer'
Rails::Initializer.run(:initialize_logger)

require 'optparse'

detach = false
ip = nil
port = nil
mime = 'config/mime.yml'

ARGV.clone.options do |opt|
  opt.on("-p", "--port=port", Integer,
          "Runs Rails on the specified port.",
          "Default: 3000") { |p| port = p }
  opt.on("-a", "--address=ip", String,
          "Binds Rails to the specified ip.",
          "Default: 0.0.0.0") { |i| ip = i }
  opt.on("-m", "--mime=path", String,
          "Path to custom mime file.",
          "Default: config/mime.yml (if it exists)") { |m| mime = m }
  opt.on('-h', '--help', 'Show this message.') { puts opt; exit 0 }
  opt.on('-d', '-d', 'Call with -d to detach') { detach = true }
  opt.parse!
end

default_port, default_ip = 3000, '0.0.0.0'
puts "=> Rails application started on http://#{ip || default_ip}:#{port || default_port}"

log_file = Pathname.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log").cleanpath

tail_thread = nil

if !detach
  puts "=> Call with -d to detach"
  puts "=> Ctrl-C to shutdown server"
  detach = false
  tail_thread = tail(log_file)
end

trap(:INT) { exit }

if File.exist?(File.join(RAILS_ROOT, mime)) && !ARGV.any? { |a| a =~ /^--?m/ }
  ARGV << "--mime=#{mime}"
end

begin
  ARGV.unshift("start")
  load 'mongrel_rails'
ensure
  unless detach
    tail_thread.kill if tail_thread
    puts 'Exiting'
  end
end
