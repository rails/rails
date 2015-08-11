module ActiveSupport
  module EachTimeWithZone #:nodoc:
    def each(&block)
      ensure_iteration_allowed
      super
    end

    def step(step_size = 1, &block)
      return to_enum(:step, step_size) unless block_given?

      # Defer to Range for steps other than durations on times
      unless step_size.is_a?(ActiveSupport::Duration) && self.begin.kind_of?(DateTime) && self.end.kind_of?(DateTime)
        ensure_iteration_allowed
        return super
      end

      # Advance through time using steps
      time = self.begin
      op = exclude_end? ? :< : :<=
      while time.send(op, self.end)
        yield time
        time = step_size.parts.inject(time) { |t, (type, number)| t.advance(type => number) }
      end

      self
    end

    private

      def ensure_iteration_allowed
        raise TypeError, "can't iterate from #{first.class}" if first.is_a?(Time)
      end
  end
end

Range.prepend(ActiveSupport::EachTimeWithZone)
