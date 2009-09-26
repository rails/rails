require 'fileutils'
require 'optparse'
require 'rails'

options = {
  :Port        => 3000,
  :Host        => "0.0.0.0",
  :environment => (ENV['RAILS_ENV'] || "development").dup,
  :config      => RAILS_ROOT + "/config.ru",
  :detach      => false,
  :debugger    => false,
  :path        => nil
}

ARGV.clone.options do |opts|
  opts.on("-p", "--port=port", Integer,
          "Runs Rails on the specified port.", "Default: #{options[:Port]}") { |v| options[:Port] = v }
  opts.on("-b", "--binding=ip", String,
          "Binds Rails to the specified ip.", "Default: #{options[:Host]}") { |v| options[:Host] = v }
  opts.on("-c", "--config=file", String,
          "Use custom rackup configuration file") { |v| options[:config] = v }
  opts.on("-d", "--daemon", "Make server run as a Daemon.") { options[:detach] = true }
  opts.on("-u", "--debugger", "Enable ruby-debugging for the server.") { options[:debugger] = true }
  opts.on("-e", "--environment=name", String,
          "Specifies the environment to run this server under (test/development/production).",
          "Default: #{options[:environment]}") { |v| options[:environment] = v }
  opts.on("-P", "--path=/path", String, "Runs Rails app mounted at a specific path.", "Default: #{options[:path]}") { |v| options[:path] = v }

  opts.separator ""

  opts.on("-h", "--help", "Show this help message.") { puts opts; exit }

  opts.parse!
end

server = Rack::Handler.get(ARGV.first) rescue nil
unless server
  begin
    server = Rack::Handler::Mongrel
  rescue LoadError => e
    server = Rack::Handler::WEBrick
  end
end

puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
puts "=> Rails #{Rails.version} application starting on http://#{options[:Host]}:#{options[:Port]}#{options[:path]}"

if options[:detach]
  Process.daemon
  pid = "#{RAILS_ROOT}/tmp/pids/server.pid"
  File.open(pid, 'w'){ |f| f.write(Process.pid) }
  at_exit { File.delete(pid) if File.exist?(pid) }
end

ENV["RAILS_ENV"] = options[:environment]
RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

app = Rails::Application.load(RAILS_ROOT, options)

puts "=> Call with -d to detach"

trap(:INT) { exit }

puts "=> Ctrl-C to shutdown server"

begin
  server.run(app, options.merge(:AccessLog => []))
ensure
  puts 'Exiting'
end
