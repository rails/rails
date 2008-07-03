require 'rbconfig'
require 'commands/servers/base'
require 'thin'


options = ARGV.clone
options.insert(0,'start') unless Thin::Runner.commands.include?(options[0])

thin = Thin::Runner.new(options)

puts "=> Rails #{Rails.version} application starting on http://#{thin.options[:address]}:#{thin.options[:port]}"
puts "=> Ctrl-C to shutdown server"

log = Pathname.new("#{File.expand_path(RAILS_ROOT)}/log/#{RAILS_ENV}.log").cleanpath
open(log, (File::WRONLY | File::APPEND | File::CREAT)) unless File.exist? log
tail_thread = tail(log)
trap(:INT) { exit }

begin
  thin.run!
ensure
  tail_thread.kill if tail_thread
  puts 'Exiting'
end

