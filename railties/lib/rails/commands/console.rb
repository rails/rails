require 'optparse'
require 'irb'
require "irb/completion"

module Rails
  class Console
    ENVIRONMENTS = %w(production development test)

    def self.start(app)
      new(app).start
    end

    def initialize(app)
      @app = app
    end

    def start
      options = {}

      OptionParser.new do |opt|
        opt.banner = "Usage: console [environment] [options]"
        opt.on('-s', '--sandbox', 'Rollback database modifications on exit.') { |v| options[:sandbox] = v }
        opt.on("--debugger", 'Enable ruby-debugging for the console.') { |v| options[:debugger] = v }
        opt.on('--irb') { |v| abort '--irb option is no longer supported. Invoke `/your/choice/of/ruby script/console` instead' }
        opt.parse!(ARGV)
      end

      if env = ARGV.first
        ENV['RAILS_ENV'] = ENVIRONMENTS.find { |e| e.index(env) } || env
      end

      @app.initialize!
      require "rails/console_app"
      require "rails/console_sandbox" if options[:sandbox]
      require "rails/console_with_helpers"

      if options[:debugger]
        begin
          require 'ruby-debug'
          puts "=> Debugger enabled"
        rescue Exception
          puts "You need to install ruby-debug to run the console in debugging mode. With gems, use 'gem install ruby-debug'"
          exit
        end
      end

      if options[:sandbox]
        puts "Loading #{Rails.env} environment in sandbox (Rails #{Rails.version})"
        puts "Any modifications you make will be rolled back on exit"
      else
        puts "Loading #{Rails.env} environment (Rails #{Rails.version})"
      end
      IRB.start
    end
  end
end
