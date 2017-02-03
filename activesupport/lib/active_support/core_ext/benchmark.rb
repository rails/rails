require "benchmark"

class << Benchmark
  # Benchmark realtime in milliseconds.
  #
  #   Benchmark.realtime { User.all }
  #   # => 8.0e-05
  #
  #   Benchmark.ms { User.all }
  #   # => 0.074
  def ms
    1000 * realtime { yield }
  end
end
