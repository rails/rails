ARGV << '--help' if ARGV.empty?

aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner"
}

help_message = <<-EOT
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
 plugin new   Generates skeleton for developing a Rails plugin
 runner       Run a piece of code in the application environment (short-cut alias: "r")

All commands can be run with -h (or --help) for more information.
EOT


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
  options = Rails::Console.parse_arguments(ARGV)

  # RAILS_ENV needs to be set before config/application is required
  ENV['RAILS_ENV'] = options[:environment] if options[:environment]

  # shift ARGV so IRB doesn't freak
  ARGV.shift if ARGV.first && ARGV.first[0] != '-'

  require APP_PATH
  Rails.application.require_environment!
  Rails::Console.start(Rails.application, options)

when 'server'
  # Change to the application's path if there is no config.ru file in current dir.
  # This allows us to run `rails server` from other directories, but still get
  # the main config.ru and properly set the tmp directory.
  Dir.chdir(File.expand_path('../../', APP_PATH)) unless File.exists?(File.expand_path("config.ru"))

  require 'rails/commands/server'
  Rails::Server.new.tap do |server|
    # We need to require application after the server sets environment,
    # otherwise the --environment option given to the server won't propagate.
    require APP_PATH
    Dir.chdir(Rails.application.root)
    server.start
  end

when 'dbconsole'
  require 'rails/commands/dbconsole'
  Rails::DBConsole.start

when 'application', 'runner'
  require "rails/commands/#{command}"

when 'new'
  if %w(-h --help).include?(ARGV.first)
    require 'rails/commands/application'
  else
    puts "Can't initialize a new Rails application within the directory of another, please change to a non-Rails directory first.\n"
    puts "Type 'rails' for help."
    exit(1)
  end

when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'

when '-h', '--help'
  puts help_message

else
  puts "Error: Command '#{command}' not recognized"
  if %x{rake #{command} --dry-run 2>&1 } && $?.success?
    puts "Did you mean: `$ rake #{command}` ?\n\n"
  end
  puts help_message
  exit(1)
end
