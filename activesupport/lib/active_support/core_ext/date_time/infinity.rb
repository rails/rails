class DateTime
  # Add additional behaviour to DateTime::Infinity to make it usable in ranges, comparison and operations with durations
  #
  # === Examples
  # DateTime::INFINITY > DateTime.civil(2018, 1, 1, 0, 0, 0)        # => true
  # -DateTime::INFINITY > Time.now                                  # => false
  # DateTime::INFINITY + 1.day                                      # => #<DateTime::Infinity:0x0...>
  # (Time.now .. DateTime::INFINITY).include?(Time.now - 1.minute)  # => false
  # (Time.now .. DateTime::INFINITY).include?(Time.now + 1.minute)  # => true
  class Infinity < Date::Infinity

    def <=>(other)
      case other
      when Date, Time
        @d
      else
        super
      end
    end

    def to_datetime
      self
    end

    def change(other)
      if other.is_a?(Numeric)
        self
      else
        raise ArgumentError, "expected numeric"
      end
    end

    alias_method :-, :change
    alias_method :+, :change
  end

  INFINITY = Infinity.new
end
