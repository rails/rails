require 'webrick'
require 'optparse'

OPTIONS = {
  :port         => 3000,
  :ip           => "0.0.0.0",
  :environment  => (ENV['RAILS_ENV'] || "development").dup,
  :server_root  => File.expand_path(RAILS_ROOT + "/public/"),
  :server_type  => WEBrick::SimpleServer,
  :charset      => "UTF-8",
  :mime_types   => WEBrick::HTTPUtils::DefaultMimeTypes,
  :debugger     => false
  
}

ARGV.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: ruby #{script_name} [options]"

  opts.separator ""

  opts.on("-p", "--port=port", Integer,
          "Runs Rails on the specified port.",
          "Default: 3000") { |v| OPTIONS[:port] = v }
  opts.on("-b", "--binding=ip", String,
          "Binds Rails to the specified ip.",
          "Default: 0.0.0.0") { |v| OPTIONS[:ip] = v }
  opts.on("-e", "--environment=name", String,
          "Specifies the environment to run this server under (test/development/production).",
          "Default: development") { |v| OPTIONS[:environment] = v }
  opts.on("-m", "--mime-types=filename", String,
                  "Specifies an Apache style mime.types configuration file to be used for mime types",
                  "Default: none") { |mime_types_file| OPTIONS[:mime_types] = WEBrick::HTTPUtils::load_mime_types(mime_types_file) }

  opts.on("-d", "--daemon",
          "Make Rails run as a Daemon (only works if fork is available -- meaning on *nix)."
          ) { OPTIONS[:server_type] = WEBrick::Daemon }

  opts.on("-u", "--debugger", "Enable ruby-debugging for the server.") { OPTIONS[:debugger] = true }

  opts.on("-c", "--charset=charset", String,
          "Set default charset for output.",
          "Default: UTF-8") { |v| OPTIONS[:charset] = v }

  opts.separator ""

  opts.on("-h", "--help",
          "Show this help message.") { puts opts; exit }

  opts.parse!
end

start_debugger if OPTIONS[:debugger]

ENV["RAILS_ENV"] = OPTIONS[:environment]
RAILS_ENV.replace(OPTIONS[:environment]) if defined?(RAILS_ENV)

require RAILS_ROOT + "/config/environment"
require 'webrick_server'

OPTIONS['working_directory'] = File.expand_path(RAILS_ROOT)

puts "=> Rails application started on http://#{OPTIONS[:ip]}:#{OPTIONS[:port]}"
puts "=> Ctrl-C to shutdown server; call with --help for options" if OPTIONS[:server_type] == WEBrick::SimpleServer
DispatchServlet.dispatch(OPTIONS)
