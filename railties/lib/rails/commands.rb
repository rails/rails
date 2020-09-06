# frozen_string_literal: true

require 'rails/command'

aliases = {
  'g'  => 'generate',
  'd'  => 'destroy',
  'c'  => 'console',
  's'  => 'server',
  'db' => 'dbconsole',
  'r'  => 'runner',
  't'  => 'test'
}

command = ARGV.shift
command = aliases[command] || command

Rails::Command.invoke command, ARGV
