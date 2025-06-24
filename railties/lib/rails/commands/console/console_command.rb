# frozen_string_literal: true

require "rails/command/environment_argument"

module Rails
  class Console
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
        IRBConsole.new(app)
      end
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

    def start
      set_environment! if environment?

      if sandbox?
        puts "Loading #{Rails.env} environment in sandbox (Rails #{Rails.version})"
        puts "Any modifications you make will be rolled back on exit"
      else
        puts "Loading #{Rails.env} environment (Rails #{Rails.version})"
      end

      console.start
    end
  end

  module Command
    class ConsoleCommand < Base # :nodoc:
      include EnvironmentArgument

      class_option :sandbox, aliases: "-s", type: :boolean, default: nil,
        desc: "Rollback database modifications on exit."

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
        Rails::Console.start(Rails.application, options)
      end
    end
  end
end
