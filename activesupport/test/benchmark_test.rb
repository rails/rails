# frozen_string_literal: true

require_relative "abstract_unit"

class BenchmarkTest < ActiveSupport::TestCase
  def test_realtime
    time = ActiveSupport::Benchmark.realtime { sleep 0.01 }
    assert_includes (0.01..0.02), time
  end

  def test_realtime_millisecond
    ms = ActiveSupport::Benchmark.realtime(:float_millisecond) { sleep 0.01 }
    assert_includes (10..20), ms
  end
end
