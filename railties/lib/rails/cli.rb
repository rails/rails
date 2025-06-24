# frozen_string_literal: true

require "rails/app_loader"

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::AppLoader.exec_app

Signal.trap("INT") { puts; exit(1) }

require "rails/command"
case ARGV.first
when Rails::Command::HELP_MAPPINGS, "help", nil
  ARGV.shift
  Rails::Command.invoke :gem_help, ARGV
when "plugin"
  ARGV.shift
  Rails::Command.invoke :plugin, ARGV
else
  Rails::Command.invoke :application, ARGV
end
