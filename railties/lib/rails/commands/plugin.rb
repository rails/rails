if ARGV.first != "new"
  ARGV[0] = "--help"
else
  ARGV.shift
end

require 'rails/generators'
require 'rails/generators/rails/plugin/plugin_generator'
Rails::Generators::PluginGenerator.start
