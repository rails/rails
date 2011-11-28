require 'active_support/core_ext/object/inclusion'

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
  puts "Error: Command not recognized" unless command.in?(['-h', '--help'])
  puts <<-EOT
Usage: rails COMMAND [ARGS]

The common rails commands available for engines are:
 generate    Generate new code (short-cut alias: "g")
 destroy     Undo code generated with "generate" (short-cut alias: "d")

All commands can be run with -h for more information.
  EOT
  exit(1)
end
