# frozen_string_literal: true

module ActiveSupport
  # Active Support \Deadline
  # =======================
  #
  # A utility class to help cooperatively timeout an execution unit.
  #
  # When a unit of work must respect an overall timeout, but call
  # into multiple sub-units with their own timeout, it may be imposible
  # to ensure the overal timeout is respected.
  #
  # Deadlines are a way to pass along the overall timeout and allow
  # sub-units to dynamically adjust their own timeout as to respect
  # the imposed deadline.
  #
  # ```
  # deadline = ActiveSupport::Deadline.new(10)
  # deadline.clamp(5) # => 5.0
  # # 8 seconds later
  # deadline.clamp(5) # => 2.0
  # # 2 more seconds later
  # deadline.clamp(5) # => raises ActiveSupport::Deadline::Exceeded
  # ```
  #
  # A typical usage is to adjust a client timeout before querying it:
  #
  # ```
  # client.timeout = deadline.clamp(DEFAULT_TIMEOUT, minimum: 0.5, error: MyClient::TimeoutError)
  # client.query(...)
  # ```
  class Deadline
    Exceeded = Class.new(StandardError)

    module Null
      class << self
        def clamp(maximum, minimum: 0.0, error: Exceeded)
          Float(maximum) # Ensure coerced to Float
        end

        def close
        end
      end
    end

    def initialize(timeout)
      @timeout = timeout
      @started_at = now
      @ends_at = @started_at + timeout
    end

    # Returns a suitable timeout to use, or raises if the
    # deadline is already exceeded.
    #
    # ```
    # deadline = ActiveSupport::Deadline.new(5)
    # deadline.clamp(10) # => 5.0
    # deadline.clamp(10, minimum: 6) # => raises ActiveSupport::Deadline::Exceeded
    # ```
    #
    # The error to raise in case of exceeded deadline can be provided through the
    # `error:` keyword argument.
    def clamp(maximum, minimum: 0.0, error: Exceeded)
      maximum = Float(maximum)
      remaining = @ends_at - now
      if remaining <= minimum
        raise error, "Deadline exceeded"
      end
      [maximum, remaining].min
    end

    # Marks the deadline as terminated, ensuring any further
    # uses will result in a Deadline::Exceeded error.
    def close
      @ends_at = -1.0
      nil
    end

    private
      def now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
  end
end
