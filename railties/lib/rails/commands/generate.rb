require 'rails/generators'
require 'active_support/core_ext/object/inclusion'

if ARGV.first.in?([nil, "-h", "--help"])
  Rails::Generators.help 'generate'
  exit
end

name = ARGV.shift

root = defined?(ENGINE_ROOT) ? ENGINE_ROOT : Rails.root
Rails::Generators.invoke name, ARGV, :behavior => :invoke, :destination_root => root
