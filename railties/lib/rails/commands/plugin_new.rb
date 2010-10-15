require 'rails/version'
if %w(--version -v).include? ARGV.first
  puts "Rails #{Rails::VERSION::STRING}"
  exit(0)
end

if ARGV.first != "new"
  ARGV[0] = "--help"
else
  ARGV.shift
end

require 'rails/generators'
require 'rails/generators/rails/plugin_new/plugin_new_generator'

Rails::Generators::PluginNewGenerator.start
