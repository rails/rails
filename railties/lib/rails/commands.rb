ARGV << '--help' if ARGV.empty?

aliases = {
  "g"  => "generate",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole"
}

command = ARGV.shift
command = aliases[command] || command

case command
when 'generate', 'destroy', 'plugin', 'benchmarker', 'profiler'
  require APP_PATH
  Rails::Application.require_environment!
  require "rails/commands/#{command}"

when 'console'
  require 'rails/commands/console'
  require APP_PATH
  Rails::Application.require_environment!
  Rails::Console.start(Rails::Application)

when 'server'
  require 'rails/commands/server'
  Rails::Server.new.tap { |server|
    require APP_PATH
    Dir.chdir(Rails::Application.root)
    server.start
  }

when 'dbconsole'
  require 'rails/commands/dbconsole'
  require APP_PATH
  Rails::DBConsole.start(Rails::Application)

when 'application', 'runner'
  require "rails/commands/#{command}"

when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'

else
  puts "Error: Command not recognized" unless %w(-h --help).include?(command)
  puts <<-EOT
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
end