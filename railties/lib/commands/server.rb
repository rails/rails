require 'active_support'

begin
  require_library_or_gem 'fcgi'
rescue Exception
  # FCGI not available
end

server = case ARGV.first
  when "lighttpd"
    ARGV.shift
  when "webrick"
    ARGV.shift
  else
    if RUBY_PLATFORM !~ /mswin/ && !silence_stderr { `lighttpd -version` }.blank? && defined?(FCGI)
      "lighttpd"
    else
      "webrick"
    end
end

if server == "webrick"
  puts "=> Booting WEBrick..."
else
  puts "=> Booting lighttpd (use 'script/server webrick' to force WEBrick)"
end

require "commands/servers/#{server}"