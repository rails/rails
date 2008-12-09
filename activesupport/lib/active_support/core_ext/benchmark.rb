require 'benchmark'

class << Benchmark
  # Earlier Ruby had a slower implementation.
  if RUBY_VERSION < '1.8.7'
    remove_method :realtime

    def realtime
      r0 = Time.now
      yield
      r1 = Time.now
      r1.to_f - r0.to_f
    end
  end

  def ms
    1000 * realtime { yield }
  end
end
