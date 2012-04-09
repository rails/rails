require 'active_support/core_ext/object/inclusion'

ARGV << '--help' if ARGV.empty?

aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner"
}

command = ARGV.shift
command = aliases[command] || command

case command
when 'generate', 'destroy', 'plugin'
  require 'rails/generators'

  if command == 'plugin' && ARGV.first == 'new'
    require "rails/commands/plugin_new"
  else
    require APP_PATH
    Rails.application.require_environment!

    Rails.application.load_generators

    require "rails/commands/#{command}"
  end

when 'benchmarker', 'profiler'
  require APP_PATH
  Rails.application.require_environment!
  require "rails/commands/#{command}"

when 'console'
  require 'rails/commands/console'
  require APP_PATH
  Rails.application.require_environment!
  Rails::Console.start(Rails.application)

when 'server'
  # Change to the application's path if there is no config.ru file in current dir.
  # This allows us to run script/rails server from other directories, but still get
  # the main config.ru and properly set the tmp directory.
  Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exists?(File.expand_path("config.ru"))

  require 'rails/commands/server'
  Rails::Server.new.tap { |server|
    # We need to require application after the server sets environment,
    # otherwise the --environment option given to the server won't propagate.
    require APP_PATH
    Dir.chdir(Rails.application.root)
    server.start
  }

when 'dbconsole'
  require 'rails/commands/dbconsole'
  require APP_PATH
  Rails::DBConsole.start(Rails.application)

when 'application', 'runner'
  require "rails/commands/#{command}"

when 'new'
  if ARGV.first.in?(['-h', '--help'])
    require 'rails/commands/application'
  else
    puts "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
    puts "Type 'rails' for help."
    exit(1)
  end

when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'

else
  puts "Error: Command not recognized" unless command.in?(['-h', '--help'])
  puts <<-EOT
Usage: rails COMMAND [ARGS]

The most common rails commands are:
 generate    Generate new code (short-cut alias: "g")
 console     Start the Rails console (short-cut alias: "c")
 server      Start the Rails server (short-cut alias: "s")
 dbconsole   Start a console for the database specified in config/database.yml
             (short-cut alias: "db")
 new         Create a new Rails application. "rails new my_app" creates a
             new application called MyApp in "./my_app"

In addition to those, there are:
 application  Generate the Rails application code
 destroy      Undo code generated with "generate" (short-cut alias: "d")
 benchmarker  See how fast a piece of code runs
 profiler     Get profile information from a piece of code
 plugin       Install a plugin
 runner       Run a piece of code in the application environment (short-cut alias: "r")

All commands can be run with -h (or --help) for more information.
  EOT
  exit(1)
end
