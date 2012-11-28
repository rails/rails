require 'fileutils'
require 'optparse'
require 'action_dispatch'

module Rails
  class Server < ::Rack::Server
    class Options
      def parse!(args)
        args, options = args.dup, {}

        opt_parser = OptionParser.new do |opts|
          opts.banner = "Usage: rails server [mongrel, thin, etc] [options]"
          opts.on("-p", "--port=port", Integer,
                  "Runs Rails on the specified port.", "Default: 3000") { |v| options[:Port] = v }
          opts.on("-b", "--binding=ip", String,
                  "Binds Rails to the specified ip.", "Default: 0.0.0.0") { |v| options[:Host] = v }
          opts.on("-c", "--config=file", String,
                  "Use custom rackup configuration file") { |v| options[:config] = v }
          opts.on("-d", "--daemon", "Make server run as a Daemon.") { options[:daemonize] = true }
          opts.on("-u", "--debugger", "Enable the debugger") { options[:debugger] = true }
          opts.on("-e", "--environment=name", String,
                  "Specifies the environment to run this server under (test/development/production).",
                  "Default: development") { |v| options[:environment] = v }
          opts.on("-P","--pid=pid",String,
                  "Specifies the PID file.",
                  "Default: tmp/pids/server.pid") { |v| options[:pid] = v }

          opts.separator ""

          opts.on("-h", "--help", "Show this help message.") { puts opts; exit }
        end

        opt_parser.parse! args

        options[:server] = args.shift
        options
      end
    end

    def initialize(*)
      super
      set_environment
    end

    def app
      @app ||= super.respond_to?(:to_app) ? super.to_app : super
    end

    def opt_parser
      Options.new
    end

    def set_environment
      ENV["RAILS_ENV"] ||= options[:environment]
    end

    def start
      url = "#{options[:SSLEnable] ? 'https' : 'http'}://#{options[:Host]}:#{options[:Port]}"
      puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
      puts "=> Rails #{Rails.version} application starting in #{Rails.env} on #{url}"
      puts "=> Call with -d to detach" unless options[:daemonize]
      trap(:INT) { exit }
      puts "=> Ctrl-C to shutdown server" unless options[:daemonize]

      #Create required tmp directories if not found
      %w(cache pids sessions sockets).each do |dir_to_make|
        FileUtils.mkdir_p(File.join(Rails.root, 'tmp', dir_to_make))
      end

      unless options[:daemonize]
        wrapped_app # touch the app so the logger is set up

        console = ActiveSupport::Logger.new($stdout)
        console.formatter = Rails.logger.formatter
        console.level = Rails.logger.level

        Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
      end

      super
    ensure
      # The '-h' option calls exit before @options is set.
      # If we call 'options' with it unset, we get double help banners.
      puts 'Exiting' unless @options && options[:daemonize]
    end

    def middleware
      middlewares = []
      middlewares << [Rails::Rack::Debugger]  if options[:debugger]
      middlewares << [::Rack::ContentLength]

      # FIXME: add Rack::Lock in the case people are using webrick.
      # This is to remain backwards compatible for those who are
      # running webrick in production. We should consider removing this
      # in development.
      if server.name == 'Rack::Handler::WEBrick'
        middlewares << [::Rack::Lock]
      end

      Hash.new(middlewares)
    end

    def log_path
      "log/#{options[:environment]}.log"
    end

    def default_options
      super.merge({
        Port:         3000,
        DoNotReverseLookup:  true,
        environment:  (ENV['RAILS_ENV'] || "development").dup,
        daemonize:    false,
        debugger:     false,
        pid:          File.expand_path("tmp/pids/server.pid"),
        config:       File.expand_path("config.ru")
      })
    end
  end
end
