require 'rbconfig'
require 'rails/script_rails_loader'

# If we are inside a Rails application this method performs an exec and thus
# the rest of this script is not run.
Rails::ScriptRailsLoader.exec_script_rails!

railties_path = File.expand_path('../../lib', __FILE__)
$:.unshift(railties_path) if File.directory?(railties_path) && !$:.include?(railties_path)

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit }

require 'rails/commands/application'
