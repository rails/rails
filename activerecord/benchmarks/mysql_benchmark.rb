require 'mysql'

conn = Mysql::real_connect("localhost", "root", "", "basecamp")

require 'benchmark'

require 'profile' if ARGV[1] == "profile"
RUNS = ARGV[0].to_i

runtime = Benchmark::measure {
  RUNS.times { 
    result = conn.query("SELECT * FROM posts LIMIT 100")
    result.each_hash { |p| p["title"] }
  }
}

puts "Runs: #{RUNS}"
puts "Avg. runtime: #{runtime.real / RUNS}"
puts "Requests/second: #{RUNS / runtime.real}"