require "active_support/core_ext/array/conversions"
require "active_support/core_ext/module/delegation"
require "active_support/core_ext/object/acts_like"
require "active_support/core_ext/string/filters"
require "active_support/deprecation"

module ActiveSupport
  # Provides accurate date and time measurements using Date#advance and
  # Time#advance, respectively. It mainly supports the methods on Numeric.
  #
  #   1.month.ago       # equivalent to Time.now.advance(months: -1)
  class Duration
    class Scalar < Numeric #:nodoc:
      attr_reader :value
      delegate :to_i, :to_f, :to_s, to: :value

      def initialize(value)
        @value = value
      end

      def coerce(other)
        [Scalar.new(other), self]
      end

      def -@
        Scalar.new(-value)
      end

      def <=>(other)
        if Scalar === other || Duration === other
          value <=> other.value
        elsif Numeric === other
          value <=> other
        else
          nil
        end
      end

      def +(other)
        if Duration === other
          seconds   = value + other.parts[:seconds]
          new_parts = other.parts.merge(seconds: seconds)
          new_value = value + other.value

          Duration.new(new_value, new_parts)
        else
          calculate(:+, other)
        end
      end

      def -(other)
        if Duration === other
          seconds   = value - other.parts[:seconds]
          new_parts = other.parts.map { |part, other_value| [part, -other_value] }.to_h
          new_parts = new_parts.merge(seconds: seconds)
          new_value = value - other.value

          Duration.new(new_value, new_parts)
        else
          calculate(:-, other)
        end
      end

      def *(other)
        if Duration === other
          new_parts = other.parts.map { |part, other_value| [part, value * other_value] }.to_h
          new_value = value * other.value

          Duration.new(new_value, new_parts)
        else
          calculate(:*, other)
        end
      end

      def /(other)
        if Duration === other
          new_parts = other.parts.map { |part, other_value| [part, value / other_value] }.to_h
          new_value = new_parts.inject(0) { |total, (part, value)| total + value * Duration::PARTS_IN_SECONDS[part] }

          Duration.new(new_value, new_parts)
        else
          calculate(:/, other)
        end
      end

      private
        def calculate(op, other)
          if Scalar === other
            Scalar.new(value.public_send(op, other.value))
          elsif Numeric === other
            Scalar.new(value.public_send(op, other))
          else
            raise_type_error(other)
          end
        end

        def raise_type_error(other)
          raise TypeError, "no implicit conversion of #{other.class} into #{self.class}"
        end
    end

    SECONDS_PER_MINUTE = 60
    SECONDS_PER_HOUR   = 3600
    SECONDS_PER_DAY    = 86400
    SECONDS_PER_WEEK   = 604800
    SECONDS_PER_MONTH  = 2629746  # 1/12 of a gregorian year
    SECONDS_PER_YEAR   = 31556952 # length of a gregorian year (365.2425 days)

    PARTS_IN_SECONDS = {
      seconds: 1,
      minutes: SECONDS_PER_MINUTE,
      hours:   SECONDS_PER_HOUR,
      days:    SECONDS_PER_DAY,
      weeks:   SECONDS_PER_WEEK,
      months:  SECONDS_PER_MONTH,
      years:   SECONDS_PER_YEAR
    }.freeze

    attr_accessor :value, :parts

    autoload :ISO8601Parser,     "active_support/duration/iso8601_parser"
    autoload :ISO8601Serializer, "active_support/duration/iso8601_serializer"

    class << self
      # Creates a new Duration from string formatted according to ISO 8601 Duration.
      #
      # See {ISO 8601}[http://en.wikipedia.org/wiki/ISO_8601#Durations] for more information.
      # This method allows negative parts to be present in pattern.
      # If invalid string is provided, it will raise +ActiveSupport::Duration::ISO8601Parser::ParsingError+.
      def parse(iso8601duration)
        parts = ISO8601Parser.new(iso8601duration).parse!
        new(calculate_total_seconds(parts), parts)
      end

      def ===(other) #:nodoc:
        other.is_a?(Duration)
      rescue ::NoMethodError
        false
      end

      def seconds(value) #:nodoc:
        new(value, [[:seconds, value]])
      end

      def minutes(value) #:nodoc:
        new(value * SECONDS_PER_MINUTE, [[:minutes, value]])
      end

      def hours(value) #:nodoc:
        new(value * SECONDS_PER_HOUR, [[:hours, value]])
      end

      def days(value) #:nodoc:
        new(value * SECONDS_PER_DAY, [[:days, value]])
      end

      def weeks(value) #:nodoc:
        new(value * SECONDS_PER_WEEK, [[:weeks, value]])
      end

      def months(value) #:nodoc:
        new(value * SECONDS_PER_MONTH, [[:months, value]])
      end

      def years(value) #:nodoc:
        new(value * SECONDS_PER_YEAR, [[:years, value]])
      end

      private

        def calculate_total_seconds(parts)
          parts.inject(0) do |total, (part, value)|
            total + value * PARTS_IN_SECONDS[part]
          end
        end
    end

    def initialize(value, parts) #:nodoc:
      @value, @parts = value, parts.to_h
      @parts.default = 0
    end

    def coerce(other) #:nodoc:
      if Scalar === other
        [other, self]
      else
        [Scalar.new(other), self]
      end
    end

    # Compares one Duration with another or a Numeric to this Duration.
    # Numeric values are treated as seconds.
    def <=>(other)
      if Duration === other
        value <=> other.value
      elsif Numeric === other
        value <=> other
      end
    end

    # Adds another Duration or a Numeric to this Duration. Numeric values
    # are treated as seconds.
    def +(other)
      if Duration === other
        parts = @parts.dup
        other.parts.each do |(key, value)|
          parts[key] += value
        end
        Duration.new(value + other.value, parts)
      else
        seconds = @parts[:seconds] + other
        Duration.new(value + other, @parts.merge(seconds: seconds))
      end
    end

    # Subtracts another Duration or a Numeric from this Duration. Numeric
    # values are treated as seconds.
    def -(other)
      self + (-other)
    end

    # Multiplies this Duration by a Numeric and returns a new Duration.
    def *(other)
      if Scalar === other || Duration === other
        Duration.new(value * other.value, parts.map { |type, number| [type, number * other.value] })
      elsif Numeric === other
        Duration.new(value * other, parts.map { |type, number| [type, number * other] })
      else
        raise_type_error(other)
      end
    end

    # Divides this Duration by a Numeric and returns a new Duration.
    def /(other)
      if Scalar === other || Duration === other
        Duration.new(value / other.value, parts.map { |type, number| [type, number / other.value] })
      elsif Numeric === other
        Duration.new(value / other, parts.map { |type, number| [type, number / other] })
      else
        raise_type_error(other)
      end
    end

    def -@ #:nodoc:
      Duration.new(-value, parts.map { |type, number| [type, -number] })
    end

    def is_a?(klass) #:nodoc:
      Duration == klass || value.is_a?(klass)
    end
    alias :kind_of? :is_a?

    def instance_of?(klass) # :nodoc:
      Duration == klass || value.instance_of?(klass)
    end

    # Returns +true+ if +other+ is also a Duration instance with the
    # same +value+, or if <tt>other == value</tt>.
    def ==(other)
      if Duration === other
        other.value == value
      else
        other == value
      end
    end

    # Returns the amount of seconds a duration covers as a string.
    # For more information check to_i method.
    #
    #   1.day.to_s # => "86400"
    def to_s
      @value.to_s
    end

    # Returns the number of seconds that this Duration represents.
    #
    #   1.minute.to_i   # => 60
    #   1.hour.to_i     # => 3600
    #   1.day.to_i      # => 86400
    #
    # Note that this conversion makes some assumptions about the
    # duration of some periods, e.g. months are always 1/12 of year
    # and years are 365.2425 days:
    #
    #   # equivalent to (1.year / 12).to_i
    #   1.month.to_i    # => 2629746
    #
    #   # equivalent to 365.2425.days.to_i
    #   1.year.to_i     # => 31556952
    #
    # In such cases, Ruby's core
    # Date[http://ruby-doc.org/stdlib/libdoc/date/rdoc/Date.html] and
    # Time[http://ruby-doc.org/stdlib/libdoc/time/rdoc/Time.html] should be used for precision
    # date and time arithmetic.
    def to_i
      @value.to_i
    end

    # Returns +true+ if +other+ is also a Duration instance, which has the
    # same parts as this one.
    def eql?(other)
      Duration === other && other.value.eql?(value)
    end

    def hash
      @value.hash
    end

    # Calculates a new Time or Date that is as far in the future
    # as this Duration represents.
    def since(time = ::Time.current)
      sum(1, time)
    end
    alias :from_now :since
    alias :after :since

    # Calculates a new Time or Date that is as far in the past
    # as this Duration represents.
    def ago(time = ::Time.current)
      sum(-1, time)
    end
    alias :until :ago
    alias :before :ago

    def inspect #:nodoc:
      parts.
        reduce(::Hash.new(0)) { |h, (l, r)| h[l] += r; h }.
        sort_by { |unit,  _ | [:years, :months, :weeks, :days, :hours, :minutes, :seconds].index(unit) }.
        map     { |unit, val| "#{val} #{val == 1 ? unit.to_s.chop : unit.to_s}" }.
        to_sentence(locale: ::I18n.default_locale)
    end

    def as_json(options = nil) #:nodoc:
      to_i
    end

    def init_with(coder) #:nodoc:
      initialize(coder["value"], coder["parts"])
    end

    def encode_with(coder) #:nodoc:
      coder.map = { "value" => @value, "parts" => @parts }
    end

    # Build ISO 8601 Duration string for this duration.
    # The +precision+ parameter can be used to limit seconds' precision of duration.
    def iso8601(precision: nil)
      ISO8601Serializer.new(self, precision: precision).serialize
    end

    private

      def sum(sign, time = ::Time.current)
        parts.inject(time) do |t, (type, number)|
          if t.acts_like?(:time) || t.acts_like?(:date)
            if type == :seconds
              t.since(sign * number)
            elsif type == :minutes
              t.since(sign * number * 60)
            elsif type == :hours
              t.since(sign * number * 3600)
            else
              t.advance(type => sign * number)
            end
          else
            raise ::ArgumentError, "expected a time or date, got #{time.inspect}"
          end
        end
      end

      def respond_to_missing?(method, _)
        value.respond_to?(method)
      end

      def method_missing(method, *args, &block)
        value.public_send(method, *args, &block)
      end

      def raise_type_error(other)
        raise TypeError, "no implicit conversion of #{other.class} into #{self.class}"
      end
  end
end
