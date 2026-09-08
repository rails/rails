# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  class Console
    HELP_HINT = "Type 'help' for help."

    def self.start(*args)
      new(*args).start
    end

    attr_reader :options, :app, :console

    def initialize(app, options = {})
      @app     = app
      @options = options

      app.sandbox = sandbox?

      if sandbox? && app.config.disable_sandbox
        puts "Error: Unable to start console in sandbox mode as sandbox mode is disabled (config.disable_sandbox is true)."
        exit 1
      end

      app.load_console

      @console = app.config.console || begin
        require "rails/commands/console/irb_console"
        IRBConsole.new(app, options)
      end
    end

    def self.startup_lines(sandbox)
      lines = if sandbox
        ["Loading #{Rails.env} environment in sandbox (Rails #{Rails.version})",
         "Any modifications you make will be rolled back on exit"]
      else
        ["Loading #{Rails.env} environment (Rails #{Rails.version})"]
      end
      lines << HELP_HINT
    end

    def sandbox?
      return options[:sandbox] if !options[:sandbox].nil?

      return false if Rails.env.local?

      app.config.sandbox_by_default
    end

    def environment
      options[:environment]
    end
    alias_method :environment?, :environment

    def set_environment!
      Rails.env = environment
    end

    # Whether to print a startup banner. Defaults to true; pass +--no-banner+
    # to suppress it for one-off sessions.
    def banner?
      options.fetch(:banner, true)
    end

    def show_default_startup_banner
      puts Rails::Console.startup_lines(sandbox?)
    end

    def start
      set_environment! if environment?

      if banner?
        show_default_startup_banner unless console.respond_to?(:show_startup_banner)
      end

      console.start
    end
  end

  module Command
    class ConsoleCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :sandbox, aliases: "-s", type: :boolean, default: nil,
        desc: "Rollback database modifications on exit."

      class_option :skip_executor, type: :boolean, aliases: "-w", desc: "Don't wrap with Rails Executor", default: false

      class_option :query_cache, type: :boolean, aliases: "-q", default: false,
        desc: "Enable the Active Record query cache for the session (ignored if --skip-executor or -w is used)"

      class_option :banner, type: :boolean, default: true,
        desc: "Show the console startup banner (use --no-banner to hide)"

      def initialize(args = [], local_options = {}, config = {})
        console_options = []

        # For the same behavior as OptionParser, leave only options after "--" in ARGV.
        termination = local_options.find_index("--")
        if termination
          console_options = local_options[termination + 1..-1]
          local_options = local_options[0...termination]
        end

        ARGV.replace(console_options)
        super(args, local_options, config)
      end

      desc "console", "Start the Rails console"
      def perform
        boot_application!

        wrap_with_executor = !options[:skip_executor]
        conditional_executor(wrap_with_executor, source: "application.console.railties") do
          disable_query_cache_in_console! if wrap_with_executor && !options[:query_cache]
          Rails::Console.start(Rails.application, options)
        end
      end

      private
        def disable_query_cache_in_console!
          return unless defined?(ActiveRecord::Base)

          ActiveRecord::Base.connection_handler.each_connection_pool.select(&:query_cache_enabled).each(&:disable_query_cache!)
        end
    end
  end
end
