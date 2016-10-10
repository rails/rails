require "rails/command"

aliases = {
  "g" => "generate",
  "d" => "destroy",
  "t" => "test"
}

command = ARGV.shift
command = aliases[command] || command

Rails::Command.invoke command, ARGV
