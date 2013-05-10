ARGV << '--help' if ARGV.empty?

aliases = {
  "g" => "generate",
  "d" => "destroy"
}

command = ARGV.shift
command = aliases[command] || command

require ENGINE_PATH
engine = ::Rails::Engine.find(ENGINE_ROOT)

case command
when 'generate', 'destroy'
  require 'rails/generators'
  Rails::Generators.namespace = engine.railtie_namespace
  engine.load_generators
  require "rails/commands/#{command}"

when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'

else
  puts "Error: Command not recognized" unless %w(-h --help).include?(command)
  puts <<-EOT
Usage: rails COMMAND [ARGS]

The common Rails commands available for engines are:
 generate    Generate new code (short-cut alias: "g")
 destroy     Undo code generated with "generate" (short-cut alias: "d")

All commands can be run with -h for more information.

If you want to run any commands that need to be run in context
of the application, like `rails server` or `rails console`,
you should do it from application's directory (typically test/dummy).
  EOT
  exit(1)
end
