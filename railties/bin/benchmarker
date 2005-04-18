#!/usr/local/bin/ruby

if ARGV.empty?
  puts "Usage: benchmarker times 'Person.expensive_way' 'Person.another_expensive_way' ..."
  exit 
end

require File.dirname(__FILE__) + '/../config/environment'
require 'benchmark'
include Benchmark

# Don't include compilation in the benchmark
ARGV[1..-1].each { |expression| eval(expression) }

bm(6) do |x|
  ARGV[1..-1].each_with_index do |expression, idx|
    x.report("##{idx + 1}") { ARGV[0].to_i.times { eval(expression) } }
  end
end 