if [nil, "-h", "--help"].include?(ARGV.first)
  puts "Usage: rails benchmarker [times] 'Person.expensive_way' 'Person.another_expensive_way' ..."
  exit 1
end

begin
  N = Integer(ARGV.first)
  ARGV.shift
rescue ArgumentError
  N = 1
end

require 'benchmark'
include Benchmark

# Don't include compilation in the benchmark
ARGV.each { |expression| eval(expression) }

bm(6) do |x|
  ARGV.each_with_index do |expression, idx|
    x.report("##{idx + 1}") { N.times { eval(expression) } }
  end
end
