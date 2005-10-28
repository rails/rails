if RUBY_PLATFORM !~ /mswin/ && `lighttpd -version 2>/dev/null`.size > 0
  puts "=> Rails application started on http://0.0.0.0:3000"

  if ARGV.first == "-d"
    puts "=> Configure in config/lighttpd.conf"
    detach = true
  else
    puts "=> Call with -d to detach; Configure in config/lighttpd.conf"
    puts "=> Ctrl-C to shutdown server (see config/lighttpd.conf for options)"
    detach = false
  end

  `lighttpd -f #{File.dirname(__FILE__) + "/../"}/config/lighttpd.conf`
else
  puts "lighttpd is not available on your system (or not in your path)"
end