require 'rails/generators'

if [nil, "-h", "--help"].include?(ARGV.first)
  Rails::Generators.help 'generate'
  exit
end

name = ARGV.shift

root = defined?(ENGINE_ROOT) ? ENGINE_ROOT : Rails.root
Rails::Generators.invoke name, ARGV, behavior: :invoke, destination_root: root
