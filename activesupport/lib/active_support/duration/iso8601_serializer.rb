# :markup: markdown
# frozen_string_literal: true

require "bigdecimal"

module ActiveSupport
  class Duration
    # Serializes duration to string according to ISO 8601 Duration format.
    class ISO8601Serializer # :nodoc:
      DATE_COMPONENTS = %i(years months days).freeze

      def initialize(duration, precision: nil)
        @duration = duration
        @precision = precision
      end

      # Builds and returns output string.
      def serialize
        parts = normalize
        return "PT0S" if parts.empty?

        output = +"P"
        output << "#{format_number(parts[:years])}Y"   if parts.key?(:years)
        output << "#{format_number(parts[:months])}M"  if parts.key?(:months)
        output << "#{format_number(parts[:days])}D"    if parts.key?(:days)
        output << "#{format_number(parts[:weeks])}W"   if parts.key?(:weeks)
        time = +""
        time << "#{format_number(parts[:hours])}H"     if parts.key?(:hours)
        time << "#{format_number(parts[:minutes])}M"   if parts.key?(:minutes)
        if parts.key?(:seconds)
          time << "#{format_seconds(parts[:seconds])}S"
        end
        output << "T#{time}" unless time.empty?
        output
      end

      private
        # Return pair of duration's parts and whole duration sign.
        # Parts are summarized (as they can become repetitive due to addition, etc).
        # Zero parts are removed as not significant.
        def normalize
          parts = @duration.parts.each_with_object(Hash.new(0)) do |(k, v), p|
            p[k] += v  unless v.zero?
          end

          # Convert weeks to days and remove weeks if mixed with date parts
          if week_mixed_with_date?(parts)
            parts[:days] += parts.delete(:weeks) * SECONDS_PER_WEEK / SECONDS_PER_DAY
          end

          parts
        end

        def week_mixed_with_date?(parts)
          parts.key?(:weeks) && parts.keys.intersect?(DATE_COMPONENTS)
        end

        def format_seconds(seconds)
          if @precision
            sprintf("%0.0#{@precision}f", seconds)
          else
            format_number(seconds)
          end
        end

        # Float#to_s uses scientific notation for very small and very large values
        # (e.g. "5.0e-05") and Rational#to_s writes a fraction ("3/2"), neither of
        # which is valid in ISO 8601.
        def format_number(number)
          case number
          when Integer
            number
          when Float
            str = number.to_s
            if str.include?("e")
              BigDecimal(str).to_s("F")
            else
              str
            end
          when Rational
            format_number(number.to_f)
          else
            number.to_s
          end
        end
    end
  end
end
