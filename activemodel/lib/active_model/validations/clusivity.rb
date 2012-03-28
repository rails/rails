
require 'active_support/core_ext/range.rb'

module ActiveModel

  module Validations
    class ClusivityValidator < EachValidator
      ERROR_MESSAGE = "An object with the method #include? or a proc or lambda is required, " <<
                      "and must be supplied as the :in option of the configuration hash"

      def check_validity!
        unless [:include?, :call].any?{ |method| options[:in].respond_to?(method) }
          raise ArgumentError, ERROR_MESSAGE
        end
      end

      def validate_each(record, attribute, value)
        delimiter = options[:in]
        exclusions = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter
        error_key, truth = self._error_key
        if exclusions.send(inclusion_method(exclusions), value) != truth
          record.errors.add(attribute, error_key, options.except(:in).merge!(:value => value))
        end
      end

    private

      # In Ruby 1.9 <tt>Range#include?</tt> on non-numeric ranges checks all possible values in the
      # range for equality, so it may be slow for large ranges. The new <tt>Range#cover?</tt>
      # uses the previous logic of comparing a value with the range endpoints.
      def inclusion_method(enumerable)
        enumerable.is_a?(Range) ? :cover? : :include?
      end
    end
  end
end
