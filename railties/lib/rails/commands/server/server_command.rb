# frozen_string_literal: true

require "fileutils"
require "optparse"
require "action_dispatch"
require "rails"
require "active_support/deprecation"
require "active_support/core_ext/string/filters"
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

    def app
      @app ||= begin
        app = super
        if app.is_a?(Class)
          ActiveSupport::Deprecation.warn(<<-MSG.squish)
            Using `Rails::Application` subclass to start the server is deprecated and will be removed in Rails 6.0.
            Please change `run #{app}` to `run Rails.application` in config.ru.
          MSG
        end
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
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super
    ensure
      yield
    end

    def serveable? # :nodoc:
      server
      true
    rescue LoadError, NameError
      false
    end

    def middleware
      Hash.new([])
    end

    def default_options
      super.merge(@default_options)
    end

    def served_url
      "#{options[:SSLEnable] ? 'https' : 'http'}://#{options[:Host]}:#{options[:Port]}" unless use_puma?
    end

    private
      def setup_dev_caching
        if options[:environment] == "development"
          Rails::DevCaching.enable_by_argument(options[:caching])
        end
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

      def use_puma?
        server.to_s == "Rack::Handler::Puma"
      end
  end

  module Command
    class ServerCommand < Base # :nodoc:
      # Hard-coding a bunch of handlers here as we don't have a public way of
      # querying them from the Rack::Handler registry.
      RACK_SERVERS = %w(cgi fastcgi webrick lsws scgi thin puma unicorn)

      DEFAULT_PORT = 3000
      DEFAULT_PID_PATH = "tmp/pids/server.pid".freeze

      argument :using, optional: true

      class_option :port, aliases: "-p", type: :numeric,
        desc: "Runs Rails on the specified port - defaults to 3000.", banner: :port
      class_option :binding, aliases: "-b", type: :string,
        desc: "Binds Rails to the specified IP - defaults to 'localhost' in development and '0.0.0.0' in other environments'.",
        banner: :IP
      class_option :config, aliases: "-c", type: :string, default: "config.ru",
        desc: "Uses a custom rackup configuration.", banner: :file
      class_option :daemon, aliases: "-d", type: :boolean, default: false,
        desc: "Runs server as a Daemon."
      class_option :environment, aliases: "-e", type: :string,
        desc: "Specifies the environment to run this server under (development/test/production).", banner: :name
      class_option :using, aliases: "-u", type: :string,
        desc: "Specifies the Rack server used to run the application (thin/puma/webrick).", banner: :name
      class_option :pid, aliases: "-P", type: :string, default: DEFAULT_PID_PATH,
        desc: "Specifies the PID file."
      class_option "dev-caching", aliases: "-C", type: :boolean, default: nil,
        desc: "Specifies whether to perform caching in development."
      class_option "restart", type: :boolean, default: nil, hide: true
      class_option "early_hints", type: :boolean, default: nil, desc: "Enables HTTP/2 early hints."

      def initialize(args = [], local_options = {}, config = {})
        @original_options = local_options
        super
        @using = deprecated_positional_rack_server(using) || options[:using]
        @log_stdout = options[:daemon].blank? && (options[:environment] || Rails.env) == "development"
      end

      def perform
        set_application_directory!
        prepare_restart

        Rails::Server.new(server_options).tap do |server|
          # Require application after server sets environment to propagate
          # the --environment option.
          require APP_PATH
          Dir.chdir(Rails.application.root)

          if server.serveable?
            print_boot_information(server.server, server.served_url)
            server.start do
              say "Exiting" unless options[:daemon]
            end
          else
            say rack_server_suggestion(using)
          end
        end
      end

      no_commands do
        def server_options
          {
            user_supplied_options: user_supplied_options,
            server:                using,
            log_stdout:            @log_stdout,
            Port:                  port,
            Host:                  host,
            DoNotReverseLookup:    true,
            config:                options[:config],
            environment:           environment,
            daemonize:             options[:daemon],
            pid:                   pid,
            caching:               options["dev-caching"],
            restart_cmd:           restart_command,
            early_hints:           early_hints
          }
        end
      end

      private
        def user_supplied_options
          @user_supplied_options ||= begin
            # Convert incoming options array to a hash of flags
            #   ["-p3001", "-C", "--binding", "127.0.0.1"] # => {"-p"=>true, "-C"=>true, "--binding"=>true}
            user_flag = {}
            @original_options.each do |command|
              if command.to_s.start_with?("--")
                option = command.split("=")[0]
                user_flag[option] = true
              elsif command =~ /\A(-.)/
                user_flag[Regexp.last_match[0]] = true
              end
            end

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
          options[:port] || ENV.fetch("PORT", DEFAULT_PORT).to_i
        end

        def host
          if options[:binding]
            options[:binding]
          else
            default_host = environment == "development" ? "localhost" : "0.0.0.0"
            ENV.fetch("HOST", default_host)
          end
        end

        def environment
          options[:environment] || Rails::Command.environment
        end

        def restart_command
          "bin/rails server #{using} #{@original_options.join(" ")} --restart"
        end

        def early_hints
          options[:early_hints]
        end

        def pid
          File.expand_path(options[:pid])
        end

        def self.banner(*)
          "rails server [thin/puma/webrick] [options]"
        end

        def prepare_restart
          FileUtils.rm_f(options[:pid]) if options[:restart]
        end

        def deprecated_positional_rack_server(value)
          if value
            ActiveSupport::Deprecation.warn(<<-MSG.squish)
              Passing the Rack server name as a regular argument is deprecated
              and will be removed in the next Rails version. Please, use the -u
              option instead.
            MSG
            value
          end
        end

        def rack_server_suggestion(server)
          if server.in?(RACK_SERVERS)
            <<~MSG
              Could not load server "#{server}". Maybe you need to the add it to the Gemfile?

                gem "#{server}"

              Run `rails server --help` for more options.
            MSG
          else
            suggestions = Rails::Command::Spellchecker.suggest(server, from: RACK_SERVERS).map(&:inspect)

            <<~MSG
              Could not find server "#{server}". Maybe you meant #{suggestions.first} or #{suggestions.second}?
              Run `rails server --help` for more options.
            MSG
          end
        end

        def print_boot_information(server, url)
          say <<~MSG
            => Booting #{ActiveSupport::Inflector.demodulize(server)}
            => Rails #{Rails.version} application starting in #{Rails.env} #{url}
            => Run `rails server --help` for more startup options
          MSG
        end
    end
  end
end
