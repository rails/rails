# frozen_string_literal: true

# :markup: markdown
require "rails/app_loader"

# If we are inside a Rails application this method runs its command and does
# not return, so the rest of this script is not run.
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
when "new", Rails::Command::VERSION_MAPPINGS
  Rails::Command.invoke :application, ARGV
else
  # Commands such as `rails server` or `rails db:migrate` only work inside an
  # application. Print the usage, but exit with a failure status so scripts
  # can tell the command did not run.
  Rails::Command.invoke :application, ["--help"]
  exit 1
end
