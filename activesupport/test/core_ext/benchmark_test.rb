# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/core_ext/benchmark"

class BenchmarkTest < ActiveSupport::TestCase
  def test_is_deprecated
    assert_deprecated(ActiveSupport.deprecator) do
      assert_kind_of Numeric, Benchmark.ms { }
    end
  end
end
