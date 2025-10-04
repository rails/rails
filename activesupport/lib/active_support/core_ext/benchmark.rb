# frozen_string_literal: true

require "benchmark"
return if Benchmark.respond_to?(:ms)

class << Benchmark
  def ms(&block) # :nodoc
    # NOTE: Please also remove the Active Support `benchmark` dependency when removing this
    ActiveSupport.deprecator.warn <<~TEXT
      `Benchmark.ms` is deprecated and will be removed in Rails 8.1 without replacement.
    TEXT
    ActiveSupport::Benchmark.realtime(:float_millisecond, &block)
  end
end
