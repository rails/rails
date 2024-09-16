# frozen_string_literal: true

require_relative "abstract_unit"

class BenchmarkTest < ActiveSupport::TestCase
  def test_realtime
    time = ActiveSupport::Benchmark.realtime { sleep 0.1 }
    assert_in_delta 0.1, time, 0.0005
  end

  def test_realtime_millisecond
    ms = ActiveSupport::Benchmark.realtime(:float_millisecond) { sleep 0.1 }
    assert_in_delta 100, ms, 0.5
  end
end
