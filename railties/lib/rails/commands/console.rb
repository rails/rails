require 'optparse'
require 'irb'
require 'irb/completion'

module Rails
  class Console
    attr_reader :options, :app, :console, :arguments

    def self.start(*args)
      new(*args).start
    end

    def initialize(app, arguments = ARGV)
      @app       = app
      @arguments = arguments
      app.load_console
      @console   = app.config.console || IRB
    end

    def options
      @options ||= begin
        options = {}

        OptionParser.new do |opt|
          opt.banner = "Usage: console [environment] [options]"
          opt.on('-s', '--sandbox', 'Rollback database modifications on exit.') { |v| options[:sandbox] = v }
          opt.on("-e", "--environment=name", String,
                  "Specifies the environment to run this console under (test/development/production).",
                  "Default: development") { |v| options[:environment] = v.strip }
          opt.on("--debugger", 'Enable ruby-debugging for the console.') { |v| options[:debugger] = v }
          opt.parse!(arguments)
        end

        options
      end
    end

    def sandbox?
      options[:sandbox]
    end

    def environment?
      options[:environment]
    end

    def set_environment!
      Rails.env = options[:environment]
    end

    def debugger?
      options[:debugger]
    end

    def start
      app.sandbox = sandbox?

      require_debugger if debugger?

      set_environment! if environment?

      if sandbox?
        puts "Loading #{Rails.env} environment in sandbox (Rails #{Rails.version})"
        puts "Any modifications you make will be rolled back on exit"
      else
        puts "Loading #{Rails.env} environment (Rails #{Rails.version})"
      end

      if defined?(console::ExtendCommandBundle)
        console::ExtendCommandBundle.send :include, Rails::ConsoleMethods
      end
      console.start
    end

    def require_debugger
      begin
        require 'ruby-debug'
        puts "=> Debugger enabled"
      rescue Exception
        puts "You need to install ruby-debug19 to run the console in debugging mode. With gems, use 'gem install ruby-debug19'"
        exit
      end
    end
  end
end

# Has to set the RAILS_ENV before config/application is required
if ARGV.first && !ARGV.first.index("-") && env = ARGV.shift # has to shift the env ARGV so IRB doesn't freak
  ENV['RAILS_ENV'] = %w(production development test).detect {|e| e =~ /^#{env}/} || env
end
