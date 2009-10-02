require File.expand_path(File.join(File.dirname(__FILE__), '..', 'generators'))
require "#{RAILS_ROOT}/config/environment"

if ARGV.size == 0
  Rails::Generators.help
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :invoke
