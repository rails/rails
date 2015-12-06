aliases = {
  "g"  => "generate",
  "d"  => "destroy",
  "c"  => "console",
  "s"  => "server",
  "db" => "dbconsole",
  "r"  => "runner",
  "t"  => "test",
}

if ARGV.empty?
  ARGV << '--help'
  command = ''
else
  command = ARGV.shift
  command = aliases[command] || command
end

require 'rails/commands/command'
require 'rails/commands/dev_cache'

Rails::Commands::Command.run(command, ARGV)
