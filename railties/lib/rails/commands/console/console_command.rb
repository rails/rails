# frozen_string_literal: true

require "rails/command/environment_argument"
require "rails/full_message_cleaner"

module Rails
  class Console
    module BacktraceCleaner
      def filter_backtrace(bt)
        if result = super
          Rails.full_message_cleaner.filter([result]).first
        end
      end
    end

    class IRBConsole
      def initialize(app)
        @app = app

        require "irb"
        require "irb/completion"

        IRB::WorkSpace.prepend(BacktraceCleaner)
        IRB::ExtendCommandBundle.include(Rails::ConsoleMethods)
      end

      def name
        "IRB"
      end

      def start
        IRB.setup(nil)

        if !Rails.env.local? && !ENV.key?("IRB_USE_AUTOCOMPLETE")
          IRB.conf[:USE_AUTOCOMPLETE] = false
        end

        env = colorized_env
        app_name = @app.class.module_parent_name.underscore.dasherize
        prompt_prefix = "#{app_name}(#{env})"

        IRB.conf[:PROMPT][:RAILS_PROMPT] = {
          PROMPT_I: "#{prompt_prefix}> ",
          PROMPT_S: "#{prompt_prefix}%l ",
          PROMPT_C: "#{prompt_prefix}* ",
          RETURN: "=> %s\n"
        }

        # Respect user's choice of prompt mode.
        IRB.conf[:PROMPT_MODE] = :RAILS_PROMPT if IRB.conf[:PROMPT_MODE] == :DEFAULT
        IRB::Irb.new.run(IRB.conf)
      end

      def colorized_env
        case Rails.env
        when "development"
          IRB::Color.colorize("dev", [:BLUE])
        when "test"
          IRB::Color.colorize("test", [:BLUE])
        when "production"
          IRB::Color.colorize("prod", [:RED])
        else
          Rails.env
        end
      end
    end

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

      @console = app.config.console || IRBConsole.new(app)
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
