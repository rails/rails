require 'rails/generators'
require 'active_support/core_ext/object/inclusion'

if ARGV.first.in?([nil, "-h", "--help"])
  Rails::Generators.help 'generate'
  exit
end

name = ARGV.shift

if defined?(ENGINE_ROOT)
  Rails::Generators.invoke name, ARGV, :behavior => :invoke, :destination_root => ENGINE_ROOT
else
  Rails::Generators.invoke name, ARGV, :behavior => :invoke, :destination_root => Rails.root
end
