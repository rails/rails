require 'active_support/core_ext/object/inclusion'

ARGV << '--help' if ARGV.empty?

aliases = {
  "g" => "generate"
}

command = ARGV.shift
command = aliases[command] || command

case command
when 'generate'
  require 'rails/generators'

  require ENGINE_PATH
  engine = ::Rails::Engine.find(ENGINE_ROOT)
  engine.load_generators

  require 'rails/commands/generate'

when '--version', '-v'
  ARGV.unshift '--version'
  require 'rails/commands/application'

else
  puts "Error: Command not recognized" unless command.in?(['-h', '--help'])
  puts <<-EOT
Usage: rails COMMAND [ARGS]

The common rails commands available for engines are:
 generate    Generate new code (short-cut alias: "g")

All commands can be run with -h for more information.
  EOT
  exit(1)
end
