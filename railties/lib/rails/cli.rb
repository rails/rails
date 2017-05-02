require "rails/app_loader"

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
