unless RUBY_PLATFORM !~ /mswin/ && !silence_stderr { `lighttpd -version` }.blank?
  puts "PROBLEM: Lighttpd is not available on your system (or not in your path)"
  exit 1
end

unless defined?(FCGI)
  puts "PROBLEM: Lighttpd requires that the FCGI Ruby bindings are installed on the system"
  exit 1
end


config_file = "#{RAILS_ROOT}/config/lighttpd.conf"

unless File.exist?(config_file)
  require 'fileutils'
  source = File.expand_path(File.join(File.dirname(__FILE__),
     "..", "..", "..", "configs", "lighttpd.conf"))
  puts "=> #{config_file} not found, copying from #{source}"
  FileUtils.cp source, config_file
end

port = IO.read(config_file).scan(/^server.port\s*=\s*(\d+)/).first rescue 3000
puts "=> Rails application started on http://0.0.0.0:#{port}"

tail_thread = nil

if ARGV.first == "-d"
  puts "=> Configure in config/lighttpd.conf"
  detach = true
else
  puts "=> Call with -d to detach (requires absolute paths in config/lighttpd.conf)"
  puts "=> Ctrl-C to shutdown server (see config/lighttpd.conf for options)"
  detach = false

  log_path = "#{RAILS_ROOT}/log/#{RAILS_ENV}.log"
  cursor = File.size(log_path)
  last_checked = Time.now
  tail_thread = Thread.new do
    File.open(log_path, 'r') do |f|
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
Thread.new { sleep 0.5; `open http://0.0.0.0:#{port}` } if RUBY_PLATFORM =~ /darwin/
`lighttpd #{!detach ? "-D " : ""}-f #{config_file}`
tail_thread.kill if tail_thread