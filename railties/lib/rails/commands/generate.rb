if ARGV.size == 0
  Rails::Generators.help
  exit
end

name = ARGV.shift
Rails::Generators.invoke name, ARGV, :behavior => :invoke
