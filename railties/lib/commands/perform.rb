if %w( benchmarker profiler ).include?(ARGV.first)
  require "#{File.dirname(__FILE__)}/perform/#{ARGV.shift}"
else
  puts "Usage: ./script/perform [benchmarker|profiler]"
end