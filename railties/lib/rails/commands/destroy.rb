require 'rails/generators'
require 'active_support/core_ext/object/inclusion'

Rails::Generators.configure!

if ARGV.first.in?([nil, "-h", "--help"])
  Rails::Generators.help 'destroy'
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :revoke, :destination_root => Rails.root
