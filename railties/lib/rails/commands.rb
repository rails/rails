ARGV << '--help' if ARGV.empty?

aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner",
  "t"  => "test",
  "rs" => "restart"
}

command = ARGV.shift
command = aliases[command] || command

require 'rails/command'

Rails::Command.run(command, ARGV)
