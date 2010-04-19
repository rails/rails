require 'benchmark'

class << Benchmark
  def ms
    1000 * realtime { yield }
  end
end
