require 'rails/generators'

if [nil, "-h", "--help"].include?(ARGV.first)
  Rails::Generators.help 'generate'
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :invoke, :destination_root => Rails.root
