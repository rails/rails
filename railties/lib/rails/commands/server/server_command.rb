# frozen_string_literal: true

require "fileutils"
require "action_dispatch"
require "rails"
require "rails/dev_caching"
require "rails/command/environment_argument"
require "rails/rackup/server"

module Rails
  class Server < Rackup::Server
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

    def opt_parser
      Options.new
    end

    def set_environment
      ENV["RAILS_ENV"] ||= options[:environment]
    end

    def start(after_stop_callback = nil)
      trap(:INT) { exit }
      create_tmp_directories
      setup_dev_caching
      log_to_stdout if options[:log_stdout]

      super()
    ensure
      after_stop_callback.call if after_stop_callback
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

        unless ActiveSupport::Logger.logger_outputs_to?(Rails.logger, STDERR, STDOUT)
          Rails.logger.broadcast_to(console)
        end
      end

      def use_puma?
        server.to_s.end_with?("Handler::Puma")
      end
  end

  module Command
    class ServerCommand < Base # :nodoc:
      include EnvironmentArgument

      RACK_HANDLER_GEMS = %w(cgi webrick scgi thin puma unicorn falcon)
      # Hard-coding a bunch of handlers here as we don't have a public way of
      # querying them from the Rackup::Handler registry.
      RACK_HANDLERS = RACK_HANDLER_GEMS + %w(fastcgi lsws)
      RECOMMENDED_SERVER = "puma"

      DEFAULT_PORT = 3000
      DEFAULT_PIDFILE = "tmp/pids/server.pid"

      class_option :port, aliases: "-p", type: :numeric,
        desc: "Run Rails on the specified port - defaults to 3000.", banner: :port
      class_option :binding, aliases: "-b", type: :string,
        desc: "Bind Rails to the specified IP - defaults to 'localhost' in development and '0.0.0.0' in other environments'.",
        banner: :IP
      class_option :config, aliases: "-c", type: :string, default: "config.ru",
        desc: "Use a custom rackup configuration.", banner: :file
      class_option :daemon, aliases: "-d", type: :boolean, default: false,
        desc: "Run server as a Daemon."
      class_option :using, aliases: "-u", type: :string,
        desc: "Specify the Rack server used to run the application (thin/puma/webrick).", banner: :name
      class_option :pid, aliases: "-P", type: :string,
        desc: "Specify the PID file. Defaults to #{DEFAULT_PIDFILE} in development."
      class_option :dev_caching, aliases: "-C", type: :boolean, default: nil,
        desc: "Specify whether to perform caching in development."
      class_option :restart, type: :boolean, default: nil, hide: true
      class_option :early_hints, type: :boolean, default: nil, desc: "Enable HTTP/2 early hints."
      class_option :log_to_stdout, type: :boolean, default: nil, optional: true,
        desc: "Whether to log to stdout. Enabled by default in development when not daemonized."

      def initialize(args, local_options, *)
        super

        @original_options = local_options - %w( --restart )
      end

      desc "server", "Start the Rails server"
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
            after_stop_callback = -> { say "Exiting" unless options[:daemon] }
            server.start(after_stop_callback)
          else
            say rack_server_suggestion(options[:using])
          end
        end
      end

      no_commands do
        def server_options
          {
            user_supplied_options: user_supplied_options,
            server:                options[:using],
            log_stdout:            log_to_stdout?,
            Port:                  port,
            Host:                  host,
            DoNotReverseLookup:    true,
            config:                options[:config],
            environment:           environment,
            daemonize:             options[:daemon],
            pid:                   pid,
            caching:               options[:dev_caching],
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
              if command.start_with?("--")
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
                when :dev_caching
                  name = :caching
                when :daemonize
                  name = :daemon
                end
                user_supplied_options << name
              end
            end
            user_supplied_options << :Host if ENV["HOST"] || ENV["BINDING"]
            user_supplied_options << :Port if ENV["PORT"]
            user_supplied_options << :pid if ENV["PIDFILE"]
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

            ENV.fetch("BINDING", default_host)
          end
        end

        def environment
          options[:environment] || Rails::Command.environment
        end

        def restart_command
          "#{executable} #{@original_options.join(" ")} --restart"
        end

        def early_hints
          options[:early_hints]
        end

        def log_to_stdout?
          options.fetch(:log_to_stdout) do
            options[:daemon].blank? && environment == "development"
          end
        end

        def pid
          default_pidfile = environment == "development" ? DEFAULT_PIDFILE : nil
          pid = options[:pid] || ENV["PIDFILE"] || default_pidfile
          File.expand_path(pid) if pid
        end

        def prepare_restart
          FileUtils.rm_f(pid) if pid && options[:restart]
        end

        def rack_server_suggestion(server)
          if server.nil?
            <<~MSG
              Could not find a server gem. Maybe you need to add one to the Gemfile?

                gem "#{RECOMMENDED_SERVER}"

              Run `#{executable} --help` for more options.
            MSG
          elsif server.in?(RACK_HANDLER_GEMS)
            <<~MSG
              Could not load server "#{server}". Maybe you need to the add it to the Gemfile?

                gem "#{server}"

              Run `#{executable} --help` for more options.
            MSG
          else
            error = CorrectableNameError.new("Could not find server '#{server}'.", server, RACK_HANDLERS)
            <<~MSG
              #{error.detailed_message}
              Run `#{executable} --help` for more options.
            MSG
          end
        end

        def print_boot_information(server, url)
          say <<~MSG
            => Booting #{ActiveSupport::Inflector.demodulize(server)}
            => Rails #{Rails.version} application starting in #{Rails.env} #{url}
            => Run `#{executable} --help` for more startup options
          MSG
        end
    end
  end
end
