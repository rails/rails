require File.expand_path(File.join(File.dirname(__FILE__), '..', 'generators'))

if ARGV.size == 0
  Rails::Generators.help
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :skip
