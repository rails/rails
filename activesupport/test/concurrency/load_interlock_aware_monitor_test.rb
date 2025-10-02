# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/concurrency/load_interlock_aware_monitor"

module ActiveSupport
  module Concurrency
    class LoadInterlockAwareMonitorTest < ActiveSupport::TestCase
      def test_deprecated_constant_resolves_to_monitor
        monitor = nil
        assert_deprecated(/ActiveSupport::Concurrency::LoadInterlockAwareMonitor is deprecated/, ActiveSupport.deprecator) do
          monitor = LoadInterlockAwareMonitor.new
        end
        assert_instance_of ::Monitor, monitor
      end

      def test_deprecated_constant_can_synchronize
        assert_deprecated(/ActiveSupport::Concurrency::LoadInterlockAwareMonitor is deprecated/, ActiveSupport.deprecator) do
          monitor = LoadInterlockAwareMonitor.new
          result = nil
          monitor.synchronize do
            result = 42
          end
          assert_equal 42, result
        end
      end
    end
  end
end
