require "rails/command"

aliases = {
  "g"         => "generate",
  "d"         => "destroy",
  "c"         => "console",
  "s"         => "server",
  "db"        => "dbconsole",
  "r"         => "runner",
  "t"         => "test",
  ""          => "help",
  "-h"        => "help",
  "-?"        => "help",
  "-help"     => "help",
  "--version" => "version",
  "-v"        => "version"
}

command = String(ARGV.shift)
command = aliases[command] || command

Rails::Command.invoke command, ARGV
