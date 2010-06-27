require 'rack/mount/utils'

module Rack::Mount
  module Analysis
    class Frequency #:nodoc:
      def initialize(*keys)
        clear
        keys.each { |key| self << key }
      end

      def clear
        @raw_keys = []
        @key_frequency = Analysis::Histogram.new
        self
      end

      def <<(key)
        raise ArgumentError unless key.is_a?(Hash)
        @raw_keys << key
        nil
      end

      def possible_keys
        @possible_keys ||= begin
          @raw_keys.map do |key|
            key.inject({}) { |requirements, (method, requirement)|
              process_key(requirements, method, requirement)
              requirements
            }
          end
        end
      end

      def process_key(requirements, method, requirement)
        if requirement.is_a?(Regexp)
          expression = Utils.parse_regexp(requirement)

          if expression.is_a?(Regin::Expression) && expression.anchored_to_line?
            expression = Regin::Expression.new(expression.reject { |e| e.is_a?(Regin::Anchor) })
            return requirements[method] = expression.to_s if expression.literal?
          end
        end

        requirements[method] = requirement
      end

      def report
        @report ||= begin
          possible_keys.each { |keys| keys.each_pair { |key, _| @key_frequency << key } }
          return [] if @key_frequency.count <= 1
          @key_frequency.keys_in_upper_quartile
        end
      end

      def expire!
        @possible_keys = @report = nil
      end
    end
  end
end
