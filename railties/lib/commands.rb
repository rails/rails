if %w( console perform process runner server ).include?(ARGV.first)
  require "#{File.dirname(__FILE__)}/process/#{ARGV.shift}"
else
  puts "Choose: console perform process runner server"
end