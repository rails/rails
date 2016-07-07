require 'rails/engine/commands_tasks'

ARGV << '--help' if ARGV.empty?

aliases = {
  "g" => "generate",
  "d" => "destroy",
  "t" => "test"
}

command = ARGV.shift
command = aliases[command] || command

Rails::Engine::CommandsTasks.new(ARGV).run_command!(command)
