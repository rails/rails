require 'rbconfig'

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
default_config_file = config_file = "#{RAILS_ROOT}/config/lighttpd.conf"

require 'optparse'
ARGV.options do |opt|
  opt.on('-c', "--config=#{config_file}", 'Specify a different lighttpd config file.') { |path| config_file = path }
  opt.on('-h', '--help', 'Show this message.') { puts opt; exit 0 }
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
  config = File.read source
  config = config.gsub "CWD", File.expand_path(RAILS_ROOT).inspect
  File.open(config_file, 'w') { |f| f.write config }
end

config = IO.read(config_file)
default_port, default_ip = 3000, '0.0.0.0'
port = config.scan(/^\s*server.port\s*=\s*(\d+)/).first rescue default_port
ip   = config.scan(/^\s*server.bind\s*=\s*"([^"]+)"/).first rescue default_ip
puts "=> Rails application started on http://#{ip || default_ip}:#{port || default_port}"

tail_thread = nil

if ARGV.first == "-d"
  puts "=> Configuration in config/lighttpd.conf"
  detach = true
else
  puts "=> Call with -d to detach"
  puts "=> Ctrl-C to shutdown server (see config/lighttpd.conf for options)"
  detach = false

  cursor = File.size(configuration.log_path)
  last_checked = Time.now
  tail_thread = Thread.new do
    File.open(configuration.log_path, 'r') do |f|
      loop do
        f.seek cursor
        if f.mtime > last_checked
          last_checked = f.mtime
          contents = f.read
          cursor += contents.length
          print contents
        end
        sleep 1
      end
    end
  end
end

trap(:INT) { exit }

begin
  `lighttpd #{!detach ? "-D " : ""}-f #{config_file}`
ensure
  unless detach
    tail_thread.kill if tail_thread
    puts 'Exiting'
  
    # Ensure FCGI processes are reaped
    ARGV.replace ['-a', 'kill']
    require 'commands/process/reaper'
  end
end
