require 'active_support/core_ext/range.rb'

module ActiveModel
  module Validations
    module Clusivity #:nodoc:
      ERROR_MESSAGE = "An object with the method #include? or a proc or lambda is required, " <<
                      "and must be supplied as the :in option of the configuration hash"

      def check_validity!
        unless [:include?, :call].any?{ |method| range.respond_to?(method) }
          raise ArgumentError, ERROR_MESSAGE
        end
      end

    private

      def include?(record, value)
        exclusions = range.respond_to?(:call) ? range.call(record) : range
        exclusions.send(inclusion_method(exclusions), value)
      end

      def range
        @range ||= options[:in] || options[:within]
      end

      # In Ruby 1.9 <tt>Range#include?</tt> on non-numeric ranges checks all possible values in the
      # range for equality, so it may be slow for large ranges. The new <tt>Range#cover?</tt>
      # uses the previous logic of comparing a value with the range endpoints.
      def inclusion_method(enumerable)
        enumerable.is_a?(Range) ? :cover? : :include?
      end
    end
  end
end
