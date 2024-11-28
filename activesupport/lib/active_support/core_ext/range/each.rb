# frozen_string_literal: true

require "active_support/time_with_zone"

module ActiveSupport
  module EachTimeWithZone # :nodoc:
    def each(&block)
      ensure_iteration_allowed
      super
    end

    def step(n = 1, &block)
      ensure_iteration_allowed

      case n
      when ActiveSupport::Duration
        duration_step(n, &block)
      else
        super
      end
    end

    private
      def ensure_iteration_allowed
        raise TypeError, "can't iterate beginless range" unless self.begin
        raise TypeError, "can't iterate from #{first.class}" if first.is_a?(TimeWithZone)
      end

      def duration_step(step, &block)
        if block_given?
          iterate(step, &block)

          self
        else
          Enumerator.new do |yielder|
            iterate(step) do |value|
              yielder << value
            end
          end
        end
      end

      def iterate(step, &block)
        value, i = self.begin, 0

        while cover?(value)
          yield value

          i += 1
          value = self.begin + (step * i)
        end
      end
  end
end

Range.prepend(ActiveSupport::EachTimeWithZone)
