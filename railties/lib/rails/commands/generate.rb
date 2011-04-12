require 'rails/generators'
require 'active_support/core_ext/object/inclusion'

Rails::Generators.configure!

if ARGV.first.in?([nil, "-h", "--help"])
  Rails::Generators.help 'generate'
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :invoke, :destination_root => Rails.root
