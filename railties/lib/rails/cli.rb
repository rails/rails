require 'rbconfig'
require 'rails/script_rails_loader'

Rails::ScriptRailsLoader.exec_script_rails!

railties_path = File.expand_path('../../lib', __FILE__)
$:.unshift(railties_path) if File.directory?(railties_path) && !$:.include?(railties_path)

require 'rails/ruby_version_check'
Signal.trap("INT") { puts; exit }

require 'rails/commands/application'
