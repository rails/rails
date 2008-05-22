require 'rbconfig'
require 'commands/servers/base'

unless RUBY_PLATFORM !~ /mswin/ && !silence_stderr { `lighttpd -version` }.blank?
  puts "PROBLEM: Lighttpd is not available on your system (or not in your path)"
  exit 1
end

unless defined?(FCGI)
  puts "PROBLEM: Lighttpd requires that the FCGI Ruby bindings are installed on the system"
  exit 1
end

require 'initializer'
configuration = Rails::Initializer.run(:initialize_logger).configuration
default_config_file = config_file = Pathname.new("#{RAILS_ROOT}/config/lighttpd.conf").cleanpath

require 'optparse'

detach = false
command_line_port = nil

ARGV.options do |opt|
  opt.on("-p", "--port=port", "Changes the server.port number in the config/lighttpd.conf") { |port| command_line_port = port }
  opt.on('-c', "--config=#{config_file}", 'Specify a different lighttpd config file.') { |path| config_file = path }
  opt.on('-h', '--help', 'Show this message.') { puts opt; exit 0 }
  opt.on('-d', '-d', 'Call with -d to detach') { detach = true; puts "=> Configuration in config/lighttpd.conf" }
  opt.parse!
end

unless File.exist?(config_file)
  if config_file != default_config_file
    puts "=> #{config_file} not found."
    exit 1
  end

  require 'fileutils'

  source = File.expand_path(File.join(File.dirname(__FILE__),
     "..", "..", "..", "configs", "lighttpd.conf"))
  puts "=> #{config_file} not found, copying from #{source}"

  FileUtils.cp(source, config_file)
end

# open the config/lighttpd.conf file and add the current user defined port setting to it
if command_line_port
  File.open(config_file, 'r+') do |config|
    lines = config.readlines

    lines.each do |line|
      line.gsub!(/^\s*server.port\s*=\s*(\d+)/, "server.port = #{command_line_port}")
    end

    config.rewind
    config.print(lines)
    config.truncate(config.pos)
  end
end

config = IO.read(config_file)
default_port, default_ip = 3000, '0.0.0.0'
port = config.scan(/^\s*server.port\s*=\s*(\d+)/).first rescue default_port
ip   = config.scan(/^\s*server.bind\s*=\s*"([^"]+)"/).first rescue default_ip
puts "=> Rails #{Rails.version} application starting on http://#{ip || default_ip}:#{port || default_port}"

tail_thread = nil

if !detach
  puts "=> Call with -d to detach"
  puts "=> Ctrl-C to shutdown server (see config/lighttpd.conf for options)"
  detach = false
  tail_thread = tail(configuration.log_path)
end

trap(:INT) { exit }

begin
  `rake tmp:sockets:clear` # Needed if lighttpd crashes or otherwise leaves FCGI sockets around
  `lighttpd #{!detach ? "-D " : ""}-f #{config_file}`
ensure
  unless detach
    tail_thread.kill if tail_thread
    puts 'Exiting'
  
    # Ensure FCGI processes are reaped
    silence_stream(STDOUT) do
      ARGV.replace ['-a', 'kill']
      require 'commands/process/reaper'
    end

    `rake tmp:sockets:clear` # Remove sockets on clean shutdown
  end
end
