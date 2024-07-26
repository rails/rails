$:.unshift(File.dirname(__FILE__) + '/../lib')
if ARGV[2]
  require 'rubygems'
  require_gem 'activerecord', ARGV[2]
else
  require 'active_record'
end

ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => "basecamp")

class Post < ActiveRecord::Base; end

require 'benchmark'

require 'profile' if ARGV[1] == "profile"
RUNS = ARGV[0].to_i

runtime = Benchmark::measure {
  RUNS.times { 
    Post.find_all(nil,nil,100).each { |p| p.title }
  }
}

puts "Runs: #{RUNS}"
puts "Avg. runtime: #{runtime.real / RUNS}"
puts "Requests/second: #{RUNS / runtime.real}"
