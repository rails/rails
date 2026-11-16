# frozen_string_literal: true

require_relative "abstract_unit"

module ActiveSupport
  class DeadlineTest < TestCase
    setup do
      @started_at = 1.0
      stub_monotonic_time(@started_at) do
        @deadline = Deadline.new(5)
      end
    end

    test "#clamp returns maximum if it doesn't exceed the deadline" do
      stub_monotonic_time(@started_at) do
        assert_equal 3.0, @deadline.clamp(3)
      end
    end

    test "#clamp returns the remaining time if the maximum exceed the deadline" do
      stub_monotonic_time(@started_at + 3.0) do
        assert_equal 2.0, @deadline.clamp(3)
      end
    end

    test "#clamp raises if the minimum exceeds the deadline" do
      stub_monotonic_time(@started_at + 3.0) do
        assert_raises Deadline::Exceeded do
          @deadline.clamp(5, minimum: 3)
        end
      end

      stub_monotonic_time(@started_at + 6.0) do
        assert_raises Deadline::Exceeded do
          @deadline.clamp(5)
        end
      end

      stub_monotonic_time(@started_at + 6.0) do
        custom_error = Class.new(StandardError)
        assert_raises custom_error do
          @deadline.clamp(5, error: custom_error)
        end
      end
    end

    test "Null#clamp always returns the maximum" do
      assert_equal 1_000.0, Deadline::Null.clamp(1_000)
    end

    private
      def stub_monotonic_time(fake_time, &block)
        real_clock_gettime = Process.method(:clock_gettime)
        Process.stub(:clock_gettime, ->(clock_id, *args) {
          if clock_id == Process::CLOCK_MONOTONIC
            fake_time
          else
            real_clock_gettime.call(clock_id, *args)
          end
        }, &block)
      end
  end
end
