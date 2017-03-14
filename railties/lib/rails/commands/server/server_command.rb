require "fileutils"
require "optparse"
require "action_dispatch"
require "rails"
require "rails/dev_caching"

module Rails
  class Server < ::Rack::Server
    class Options
      def parse!(args)
        Rails::Command::ServerCommand.new([], args).server_options
      end
    end

    def initialize(options = nil)
      @default_options = options || {}
      super(@default_options)
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
      super.merge(@default_options)
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
    class ServerCommand < Base # :nodoc:
      DEFAULT_PID_PATH = "tmp/pids/server.pid".freeze

      class_option :port, aliases: "-p", type: :numeric,
        desc: "Runs Rails on the specified port.", banner: :port, default: 3000
      class_option :binding, aliases: "-b", type: :string,
        desc: "Binds Rails to the specified IP - defaults to 'localhost' in development and '0.0.0.0' in other environments'.",
        banner: :IP
      class_option :config, aliases: "-c", type: :string, default: "config.ru",
        desc: "Uses a custom rackup configuration.", banner: :file
      class_option :daemon, aliases: "-d", type: :boolean, default: false,
        desc: "Runs server as a Daemon."
      class_option :environment, aliases: "-e", type: :string,
        desc: "Specifies the environment to run this server under (development/test/production).", banner: :name
      class_option :pid, aliases: "-P", type: :string, default: DEFAULT_PID_PATH,
        desc: "Specifies the PID file."
      class_option "dev-caching", aliases: "-C", type: :boolean, default: nil,
        desc: "Specifies whether to perform caching in development."

      def initialize(args = [], local_options = {}, config = {})
        @original_options = local_options
        super
        @server = self.args.shift
        @log_stdout = options[:daemon].blank? && (options[:environment] || Rails.env) == "development"
      end

      def perform
        set_application_directory!
        Rails::Server.new(server_options).tap do |server|
          # Require application after server sets environment to propagate
          # the --environment option.
          require APP_PATH
          Dir.chdir(Rails.application.root)
          server.start
        end
      end

      no_commands do
        def server_options
          {
            user_supplied_options: user_supplied_options,
            server:                @server,
            log_stdout:            @log_stdout,
            Port:                  port,
            Host:                  host,
            DoNotReverseLookup:    true,
            config:                options[:config],
            environment:           environment,
            daemonize:             options[:daemon],
            pid:                   pid,
            caching:               options["dev-caching"],
            restart_cmd:           restart_command
          }
        end
      end

      private
        def user_supplied_options
          @user_supplied_options ||= begin
            # Convert incoming options array to a hash of flags
            #   ["-p", "3001", "-c", "foo"] # => {"-p" => true, "-c" => true}
            user_flag = {}
            @original_options.each_with_index { |command, i| user_flag[command] = true if i.even? }

            # Collect all options that the user has explicitly defined so we can
            # differentiate them from defaults
            user_supplied_options = []
            self.class.class_options.select do |key, option|
              if option.aliases.any? { |name| user_flag[name] } || user_flag["--#{option.name}"]
                name = option.name.to_sym
                case name
                when :port
                  name = :Port
                when :binding
                  name = :Host
                when :"dev-caching"
                  name = :caching
                when :daemonize
                  name = :daemon
                end
                user_supplied_options << name
              end
            end
            user_supplied_options << :Host if ENV["HOST"]
            user_supplied_options << :Port if ENV["PORT"]
            user_supplied_options.uniq
          end
        end

        def port
          ENV.fetch("PORT", options[:port]).to_i
        end

        def host
          unless (default_host = options[:binding])
            default_host = environment == "development" ? "localhost" : "0.0.0.0"
          end
          ENV.fetch("HOST", default_host)
        end

        def environment
          options[:environment] || Rails::Command.environment
        end

        def restart_command
          "bin/rails server #{@server} #{@original_options.join(" ")}"
        end

        def pid
          File.expand_path(options[:pid])
        end

        def self.banner(*)
          "rails server [puma, thin etc] [options]"
        end
    end
  end
end
