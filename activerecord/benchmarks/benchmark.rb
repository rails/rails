$:.unshift(File.dirname(__FILE__) + '/../lib')
if ARGV[2]
  require 'rubygems'
  gem 'activerecord', ARGV[2]
else
  require 'active_record'
end

ActiveRecord::Base.establish_connection(:adapter => "mysql", :database => "basecamp")

class Post < ActiveRecord::Base; end

require 'benchmark'

RUNS = ARGV[0].to_i
if ARGV[1] == "profile" then require 'profile' end

runtime = Benchmark::measure {
  RUNS.times { 
    Post.find_all(nil,nil,100).each { |p| p.title }
  }
}

puts "Runs: #{RUNS}"
puts "Avg. runtime: #{runtime.real / RUNS}"
puts "Requests/second: #{RUNS / runtime.real}"
