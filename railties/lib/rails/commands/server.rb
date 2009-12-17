require 'fileutils'
require 'optparse'
require 'action_dispatch'

module Rails
  class Server < ::Rack::Server
    class Options
      def parse!(args)
        options = {}
        args    = args.dup
        opt_parser = OptionParser.new do |opts|
          opts.on("-p", "--port=port", Integer,
                  "Runs Rails on the specified port.", "Default: #{options[:Port]}") { |v| options[:Port] = v }
          opts.on("-b", "--binding=ip", String,
                  "Binds Rails to the specified ip.", "Default: #{options[:Host]}") { |v| options[:Host] = v }
          opts.on("-c", "--config=file", String,
                  "Use custom rackup configuration file") { |v| options[:config] = v }
          opts.on("-d", "--daemon", "Make server run as a Daemon.") { options[:daemonize] = true }
          opts.on("-u", "--debugger", "Enable ruby-debugging for the server.") { options[:debugger] = true }
          opts.on("-e", "--environment=name", String,
                  "Specifies the environment to run this server under (test/development/production).",
                  "Default: #{options[:environment]}") { |v| options[:environment] = v }

          opts.separator ""

          opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
        end

        opt_parser.parse! args

        options[:server] = args.shift
        options
      end
    end

    def opt_parser
      Options.new
    end

    def self.start(app)
      new(app).start
    end

    def initialize(app_const)
      super() # Call Rack::Server#initialize without passing any options to use.
      @app_const = app_const
    end

    def start
      puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
      puts "=> Rails #{Rails.version} application starting on http://#{options[:Host]}:#{options[:Port]}"
      puts "=> Call with -d to detach" unless options[:daemonize]
      trap(:INT) { exit }
      puts "=> Ctrl-C to shutdown server" unless options[:daemonize]

      ENV["RAILS_ENV"] = options[:environment]
      RAILS_ENV.replace(options[:environment]) if defined?(RAILS_ENV)

      super
    ensure
      puts 'Exiting' unless options[:daemonize]
    end

    def middleware
      middlewares = []
      middlewares << [Rails::Rack::LogTailer, log_path] unless options[:daemonize]
      middlewares << [Rails::Rack::Debugger]  if options[:debugger]
      Hash.new(middlewares)
    end

    def log_path
      "#{File.expand_path(@app_const.root)}/log/#{options[:environment]}.log"
    end

    def default_options
      {
        :Port        => 3000,
        :Host        => "0.0.0.0",
        :environment => (ENV['RAILS_ENV'] || "development").dup,
        :rack_file   => "#{@app_const.root}/config.ru",
        :daemonize   => false,
        :debugger    => false,
        :pid         => "#{@app_const.root}/tmp/pids/server.pid",
        :AccessLog   => []
      }
    end
  end
end
