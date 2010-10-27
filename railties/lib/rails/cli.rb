require 'rbconfig'
require 'rails/script_rails_loader'

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::ScriptRailsLoader.exec_script_rails!

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit }

require 'rails/commands/application'
