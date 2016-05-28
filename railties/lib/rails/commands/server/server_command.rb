require "fileutils"
require "optparse"
require "action_dispatch"
require "rails"
require "rails/dev_caching"

module Rails
  class Server < ::Rack::Server
    class Options
      DEFAULT_PID_PATH = File.expand_path("tmp/pids/server.pid").freeze

      def parse!(args)
        args, options = args.dup, {}

        option_parser(options).parse! args

        options[:log_stdout] = options[:daemonize].blank? && (options[:environment] || Rails.env) == "development"
        options[:server]     = args.shift
        options
      end

      def option_parser(options) # :nodoc:
        OptionParser.new do |opts|
          opts.banner = "Usage: rails server [mongrel, thin etc] [options]"

          opts.separator ""
          opts.separator "Options:"

          opts.on("-p", "--port=port", Integer,
                  "Runs Rails on the specified port.", "Default: 3000") { |v| options[:Port] = v }
          opts.on("-b", "--binding=IP", String,
                  "Binds Rails to the specified IP.", "Default: localhost") { |v| options[:Host] = v }
          opts.on("-c", "--config=file", String,
                  "Uses a custom rackup configuration.") { |v| options[:config] = v }
          opts.on("-d", "--daemon", "Runs server as a Daemon.") { options[:daemonize] = true }
          opts.on("-e", "--environment=name", String,
                  "Specifies the environment to run this server under (test/development/production).",
                  "Default: development") { |v| options[:environment] = v }
          opts.on("-P", "--pid=pid", String,
                  "Specifies the PID file.",
                  "Default: tmp/pids/server.pid") { |v| options[:pid] = v }
          opts.on("-C", "--[no-]dev-caching",
                  "Specifies whether to perform caching in development.",
                  "true or false") { |v| options[:caching] = v }

          opts.separator ""

          opts.on("-h", "--help", "Shows this help message.") { puts opts; exit }
        end
      end
    end

    def initialize(*)
      super
      set_environment
    end

    # TODO: this is no longer required but we keep it for the moment to support older config.ru files.
    def app
      @app ||= begin
        app = super
        app.respond_to?(:to_app) ? app.to_app : app
      end
    end

    def opt_parser
      Options.new
    end

    def set_environment
      ENV["RAILS_ENV"] ||= options[:environment]
    end

    def start
      print_boot_information
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super
    ensure
      # The '-h' option calls exit before @options is set.
      # If we call 'options' with it unset, we get double help banners.
      puts "Exiting" unless @options && options[:daemonize]
    end

    def middleware
      Hash.new([])
    end

    def default_options
      super.merge(        Port:               ENV.fetch("PORT", 3000).to_i,
        DoNotReverseLookup: true,
        environment:        (ENV["RAILS_ENV"] || ENV["RACK_ENV"] || "development").dup,
        daemonize:          false,
        caching:            nil,
        pid:                Options::DEFAULT_PID_PATH,
        restart_cmd:        restart_command)
    end

    private

      def setup_dev_caching
        if options[:environment] == "development"
          Rails::DevCaching.enable_by_argument(options[:caching])
        end
      end

      def print_boot_information
        url = "#{options[:SSLEnable] ? 'https' : 'http'}://#{options[:Host]}:#{options[:Port]}"
        puts "=> Booting #{ActiveSupport::Inflector.demodulize(server)}"
        puts "=> Rails #{Rails.version} application starting in #{Rails.env} on #{url}"
        puts "=> Run `rails server -h` for more startup options"
      end

      def create_tmp_directories
        %w(cache pids sockets).each do |dir_to_make|
          FileUtils.mkdir_p(File.join(Rails.root, "tmp", dir_to_make))
        end
      end

      def log_to_stdout
        wrapped_app # touch the app so the logger is set up

        console = ActiveSupport::Logger.new(STDOUT)
        console.formatter = Rails.logger.formatter
        console.level = Rails.logger.level

        unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDOUT)
          Rails.logger.extend(ActiveSupport::Logger.broadcast(console))
        end
      end

      def restart_command
        "bin/rails server #{ARGV.join(' ')}"
      end
  end

  module Command
    class ServerCommand < Base
      def help # :nodoc:
        puts Rails::Server::Options.new.option_parser(Hash.new)
      end

      def perform
        set_application_directory!

        Rails::Server.new.tap do |server|
          # Require application after server sets environment to propagate
          # the --environment option.
          require APP_PATH
          Dir.chdir(Rails.application.root)
          server.start
        end
      end
    end
  end
end
