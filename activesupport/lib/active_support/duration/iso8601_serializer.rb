# :markup: markdown
# frozen_string_literal: true

module ActiveSupport
  class Duration
    # Serializes duration to string according to ISO 8601 Duration format.
    class ISO8601Serializer # :nodoc:
      DATE_COMPONENTS = %i(years months days).freeze
      TIME_COMPONENTS = %i(hours minutes seconds).freeze

      def initialize(duration, precision: nil)
        @duration = duration
        @precision = precision
      end

      # Builds and returns output string.
      def serialize
        parts = normalize
        return "PT0S" if parts.empty?

        output = +"P"
        output << "#{parts[:years]}Y"   if parts.key?(:years)
        output << "#{parts[:months]}M"  if parts.key?(:months)
        output << "#{parts[:days]}D"    if parts.key?(:days)
        output << "#{parts[:weeks]}W"   if parts.key?(:weeks)
        time = +""
        time << "#{parts[:hours]}H"     if parts.key?(:hours)
        time << "#{parts[:minutes]}M"   if parts.key?(:minutes)
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

          carry_fractions(parts)

          parts
        end

        # ISO 8601 only allows the smallest component to have a fraction, so a
        # fraction followed by smaller components is moved into the next one
        # down, the same way Time#advance applies fractional weeks and days.
        def carry_fractions(parts)
          if fractional?(parts[:weeks]) && parts.keys.intersect?(TIME_COMPONENTS)
            parts[:days] += parts.delete(:weeks) * SECONDS_PER_WEEK / SECONDS_PER_DAY
          end

          [[:days, :hours, 24], [:hours, :minutes, 60], [:minutes, :seconds, 60]].each do |from, to, factor|
            next unless fractional?(parts[from])
            next unless parts.keys.intersect?(TIME_COMPONENTS.drop_while { |part| part != to })

            whole = parts[from].truncate
            carried = (parts[from] - whole) * factor
            carried = carried.to_i if carried % 1 == 0
            whole.zero? ? parts.delete(from) : parts[from] = whole
            parts[to] += carried
          end
        end

        def fractional?(value)
          !value.nil? && value % 1 != 0
        end

        def week_mixed_with_date?(parts)
          parts.key?(:weeks) && parts.keys.intersect?(DATE_COMPONENTS)
        end

        def format_seconds(seconds)
          if @precision
            sprintf("%0.0#{@precision}f", seconds)
          else
            seconds.to_s
          end
        end
    end
  end
end
