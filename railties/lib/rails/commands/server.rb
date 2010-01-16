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

    def start
      ENV["RAILS_ENV"] = options[:environment]

      puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
      puts "=> Rails #{Rails.version} application starting in #{Rails.env} on http://#{options[:Host]}:#{options[:Port]}"
      puts "=> Call with -d to detach" unless options[:daemonize]
      trap(:INT) { exit }
      puts "=> Ctrl-C to shutdown server" unless options[:daemonize]

      initialize_log_tailer! unless options[:daemonize]
      super
    ensure
      puts 'Exiting' unless options[:daemonize]
    end

    def middleware
      middlewares = []
      middlewares << [Rails::Rack::Debugger]  if options[:debugger]
      Hash.new(middlewares)
    end

    def log_path
      "log/#{options[:environment]}.log"
    end

    def default_options
      super.merge({
        :Port        => 3000,
        :environment => (ENV['RAILS_ENV'] || "development").dup,
        :daemonize   => false,
        :debugger    => false,
        :pid         => "tmp/pids/server.pid"
      })
    end

  protected

    # LogTailer should not be used as a middleware since the logging happens
    # async in a request and the middleware calls are sync. So we send it
    # to subscriber which will be responsible for calling tail! in the log tailer.
    def initialize_log_tailer!
      Rails::Subscriber.log_tailer = Rails::Rack::LogTailer.new(nil, log_path)
    end
  end
end
