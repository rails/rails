if ARGV.empty?
  ARGV << '--help'
end

HELP_TEXT = <<-EOT
Usage: rails COMMAND [ARGS]

The most common rails commands are:
 generate    Generate new code (short-cut alias: "g")
 console     Start the Rails console (short-cut alias: "c")
 server      Start the Rails server (short-cut alias: "s")
 dbconsole   Start a console for the database specified in config/database.yml
             (short-cut alias: "db")

In addition to those, there are:
 application  Generate the Rails application code
 destroy      Undo code generated with "generate"
 benchmarker  See how fast a piece of code runs
 profiler     Get profile information from a piece of code
 plugin       Install a plugin
 runner       Run a piece of code in the application environment

All commands can be run with -h for more information.
EOT


case ARGV.shift
when 'g', 'generate'
  require ENV_PATH
  require 'rails/commands/generate'
when 'c', 'console'
  require 'rails/commands/console'
  require ENV_PATH
  Rails::Console.start(Rails::Application)
when 's', 'server'
  require 'rails/commands/server'
  # Initialize the server first, so environment options are set
  server = Rails::Server.new
  require APP_PATH

  Dir.chdir(Rails::Application.root)
  server.start
when 'db', 'dbconsole'
  require 'rails/commands/dbconsole'
  require APP_PATH
  Rails::DBConsole.start(Rails::Application)

when 'application'
  require 'rails/commands/application'
when 'destroy'
  require ENV_PATH
  require 'rails/commands/destroy'
when 'benchmarker'
  require ENV_PATH
  require 'rails/commands/performance/benchmarker'
when 'profiler'
  require ENV_PATH
  require 'rails/commands/performance/profiler'
when 'plugin'
  require APP_PATH
  require 'rails/commands/plugin'
when 'runner'
  require 'rails/commands/runner'

when '--help', '-h'
  puts HELP_TEXT
when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'
else
  puts "Error: Command not recognized"
  puts HELP_TEXT
end
