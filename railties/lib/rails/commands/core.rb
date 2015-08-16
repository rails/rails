require 'rails/commands/command'

module Rails
  module Commands
    # This is a wrapper around all base Rails tasks, including but not
    # limited to: generate, console, server, test, dbconsole, new, etc.
    class Core < Command
      rake_delegate 'initializers', 'stats', 'secret', 'time:zones:all', 
        'routes', 'about', 'middleware', 'rails:template', 'rails:update',
        'log:clear'

      set_banner :initializers,
        'Print out all defined initializers in the order they are invoked by Rails'
      set_banner :restart,
        'Restart app by touching tmp/restart.txt'
      set_banner :stats, 
        'Report code statistics (KLOCs, etc) from the application or engine'
      set_banner :secret, 
        'Generate a cryptographically secure secret key (this is typically used to generate a secret for cookie sessions)'
      set_banner :time_zones_all, 
        'Displays all time zones, also available: time:zones:us, time:zones:local -- filter with OFFSET parameter, e.g., OFFSET=-6'
      set_banner :routes, 
        'Print out all defined routes in match order, with names'
      set_banner :about, 
        'List versions of all Rails frameworks and the environment'
      set_banner :middleware,
        'Prints out your Rack middleware stack'
      set_banner :template, 
        'Applies the template supplied by LOCATION=(/path/to/template) or URL'
      set_banner :update,
        'Update configs and some other initially generated files (or use just update:configs or update:bin'
      set_banner :log_clear,
        'Truncates all *.log files in log/ to zero bytes (specify which logs with LOGS=test,development)'

      # Remove these when rails:template and rails:update is rewritten
      alias_method :template, :rails_template
      alias_method :update,   :rails_update

      def require_command!(command)
        require "rails/commands/#{command}"
      end

      def plugin
        require_command!("plugin")
      end

      def generate_or_destroy(command)
        require 'rails/generators'
        require_application_and_environment!
        Rails.application.load_generators
        require_command!(command)
      end

      def generate
        generate_or_destroy(:generate)
      end
      alias_method :g, :generate

      def destroy
        generate_or_destroy(:destroy)
      end
      alias_method :d, :destroy

      def console
        require_command!("console")
        options = Rails::Console.parse_arguments(argv)

        # RAILS_ENV needs to be set before config/application is required
        ENV['RAILS_ENV'] = options[:environment] if options[:environment]

        # shift ARGV so IRB doesn't freak
        shift_argv!

        require_application_and_environment!
        Rails::Console.start(Rails.application, options)
      end
      alias_method :c, :console

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
      alias_method :s, :server

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

      def version
        argv.unshift '--version'
        require_command!("application")
      end

      private

        def exit_with_initialization_warning!
          puts "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
          puts "Type 'rails' for help."
          exit(1)
        end

        def shift_argv!
          argv.shift if argv.first && argv.first[0] != '-'
        end

        # Change to the application's path if there is no config.ru file in current directory.
        # This allows us to run `rails server` from other directories, but still get
        # the main config.ru and properly set the tmp directory.
        def set_application_directory!
          Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exist?(File.expand_path("config.ru"))
        end

        def require_application_and_environment!
          require APP_PATH
          Rails.application.require_environment!
        end
    end
  end
end
