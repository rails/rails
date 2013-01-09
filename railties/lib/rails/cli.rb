require 'rbconfig'
require 'rails/app_rails_loader'

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
#
# TODO: when we hit this, advise adding ./bin to $PATH instead. Then the
# app's `rails` executable is run immediately.
Rails::AppRailsLoader.exec_app_rails

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit(1) }

if ARGV.first == 'plugin'
  ARGV.shift
  require 'rails/commands/plugin_new'
else
  require 'rails/commands/application'
end
