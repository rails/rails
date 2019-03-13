# frozen_string_literal: true

require "rails/app_loader"

if File.expand_path($0) == File.expand_path("bin/rails")
  Object.const_set(:APP_PATH, File.expand_path("config/application", Dir.pwd))
  require File.expand_path("../boot", APP_PATH)
  require "rails/commands"
  return
end

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::AppLoader.exec_app

require "rails/ruby_version_check"
Signal.trap("INT") { puts; exit(1) }

require "rails/command"

if ARGV.first == "plugin"
  ARGV.shift
  Rails::Command.invoke :plugin, ARGV
else
  Rails::Command.invoke :application, ARGV
end
