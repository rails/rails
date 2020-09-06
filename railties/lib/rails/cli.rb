# frozen_string_literal: true

require 'rails/app_loader'

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::AppLoader.exec_app

require 'rails/ruby_version_check'
Signal.trap('INT') { puts; exit(1) }

require 'rails/command'

if ARGV.first == 'plugin'
  ARGV.shift
  Rails::Command.invoke :plugin, ARGV
else
  Rails::Command.invoke :application, ARGV
end
