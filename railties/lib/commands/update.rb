RAILS_ENV.replace "generators"
require "#{RAILS_ROOT}/config/environment"

if ARGV.size == 0
  Rails::Generators.help
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :skip
