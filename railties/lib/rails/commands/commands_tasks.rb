require "rails/commands/rake_proxy"
require "rails/commands/common_commands_tasks"
require "active_support/core_ext/string/strip"

module Rails
  # This is a class which takes in a rails command and initiates the appropriate
  # initiation sequence.
  #
  # Warning: This class mutates ARGV because some commands require manipulating
  # it before they are run.
  class CommandsTasks # :nodoc:
    include Rails::RakeProxy
    include Rails::CommonCommandsTasks

    attr_reader :argv

    ADDITIONAL_COMMANDS = [
      [ "destroy", 'Undo code generated with "generate" (short-cut alias: "d")' ],
      [ "plugin new", "Generates skeleton for developing a Rails plugin" ],
      [ "runner",
        'Run a piece of code in the application environment (short-cut alias: "r")' ]
    ]

    def initialize(argv)
      @argv = argv
    end

    def plugin
      require_command!("plugin")
    end

    def console
      require_command!("console")
      options = Rails::Console.parse_arguments(argv)

      # RAILS_ENV needs to be set before config/application is required
      ENV["RAILS_ENV"] = options[:environment] if options[:environment]

      # shift ARGV so IRB doesn't freak
      shift_argv!

      require_application_and_environment!
      Rails::Console.start(Rails.application, options)
    end

    def server
      set_application_directory!
      require_command!("server")

      Rails::Server.new.tap do |server|
        # We need to require application after the server sets environment,
        # otherwise the --environment option given to the server won't propagate.
        require APP_PATH
        Dir.chdir(Rails.application.root)
        server.start
      end
    end

    def dbconsole
      require_command!("dbconsole")
      Rails::DBConsole.start
    end

    def runner
      require_command!("runner")
    end

    def new
      if %w(-h --help).include?(argv.first)
        require_command!("application")
      else
        exit_with_initialization_warning!
      end
    end

    private

      def exit_with_initialization_warning!
        puts "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
        puts "Type 'rails' for help."
        exit(1)
      end

      def shift_argv!
        argv.shift if argv.first && argv.first[0] != "-"
      end

      # Change to the application's path if there is no config.ru file in current directory.
      # This allows us to run `rails server` from other directories, but still get
      # the main config.ru and properly set the tmp directory.
      def set_application_directory!
        Dir.chdir(File.expand_path("../../", APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
      end

      def commands
        ADDITIONAL_COMMANDS + formatted_rake_tasks
      end

      def command_whitelist
        %w(plugin generate destroy console server dbconsole runner new version help test)
      end

      def help_message
        <<-EOT.strip_heredoc
          Usage: rails COMMAND [ARGS]

          The most common rails commands are:
           generate    Generate new code (short-cut alias: "g")
           console     Start the Rails console (short-cut alias: "c")
           server      Start the Rails server (short-cut alias: "s")
           test        Run tests (short-cut alias: "t")
           dbconsole   Start a console for the database specified in config/database.yml
                       (short-cut alias: "db")
           new         Create a new Rails application. "rails new my_app" creates a
                       new application called MyApp in "./my_app"

          All commands can be run with -h (or --help) for more information.

          In addition to those commands, there are:
        EOT
      end

      def require_application_and_environment!
        require APP_PATH
        Rails.application.require_environment!
      end

      def load_tasks
        Rails.application.load_tasks
      end

      def load_generators
        Rails.application.load_generators
      end
  end
end
