module Rack::Mount
  module Analysis
    class Histogram < Hash #:nodoc:
      attr_reader :count

      def initialize
        @count = 0
        super(0)
        expire_caches!
      end

      def <<(value)
        @count += 1
        self[value] += 1 if value
        expire_caches!
        self
      end

      def sorted_by_frequency
        sort_by { |_, value| value }.reverse!
      end

      def max
        @max ||= values.max || 0
      end

      def min
        @min ||= values.min || 0
      end

      def mean
        @mean ||= calculate_mean
      end

      def standard_deviation
        @standard_deviation ||= calculate_standard_deviation
      end

      def upper_quartile_limit
        @upper_quartile_limit ||= calculate_upper_quartile_limit
      end

      def keys_in_upper_quartile
        @keys_in_upper_quartile ||= compute_keys_in_upper_quartile
      end

      private
        def calculate_mean
          count / size
        end

        def calculate_variance
          values.inject(0) { |sum, e| sum + (e - mean) ** 2 } / count.to_f
        end

        def calculate_standard_deviation
          Math.sqrt(calculate_variance)
        end

        def calculate_upper_quartile_limit
          mean + standard_deviation
        end

        def compute_keys_in_upper_quartile
          sorted_by_frequency.select { |_, value| value >= upper_quartile_limit }.map! { |key, _| key }
        end

        def expire_caches!
          @max = @min = @mean = @standard_deviation = nil
          @keys_in_upper_quartile = nil
        end
    end
  end
end
