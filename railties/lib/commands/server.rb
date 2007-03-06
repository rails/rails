require 'active_support'
require 'fileutils'

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
  when "lighttpd", "mongrel", "webrick"
    ARGV.shift
  else
    if defined?(Mongrel)
      "mongrel"
    elsif RUBY_PLATFORM !~ /(:?mswin|mingw)/ && !silence_stderr { `lighttpd -version` }.blank? && defined?(FCGI)
      "lighttpd"
    else
      "webrick"
    end
end

case server
  when "webrick"
    puts "=> Booting WEBrick..."
  when "lighttpd"
    puts "=> Booting lighttpd (use 'script/server webrick' to force WEBrick)"
  when "mongrel"
    puts "=> Booting Mongrel (use 'script/server webrick' to force WEBrick)"
end

%w(cache pids sessions sockets).each { |dir_to_make| FileUtils.mkdir_p(File.join(RAILS_ROOT, 'tmp', dir_to_make)) }
require "commands/servers/#{server}"
