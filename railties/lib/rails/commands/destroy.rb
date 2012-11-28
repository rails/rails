require 'rails/generators'

if [nil, "-h", "--help"].include?(ARGV.first)
  Rails::Generators.help 'destroy'
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, behavior: :revoke, destination_root: Rails.root
