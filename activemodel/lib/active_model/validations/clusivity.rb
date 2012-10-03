require 'active_support/core_ext/range'

module ActiveModel
  module Validations
    module Clusivity #:nodoc:
      ERROR_MESSAGE = "An object with the method #include? or a proc, lambda or symbol is required, " <<
                      "and must be supplied as the :in (or :within) option of the configuration hash"

      def check_validity!
        unless delimiter.respond_to?(:include?) || delimiter.respond_to?(:call) || delimiter.respond_to?(:to_sym)
          raise ArgumentError, ERROR_MESSAGE
        end
      end

    private

      def include?(record, value)
        exclusions = if delimiter.respond_to?(:call)
                       delimiter.call(record)
                     elsif delimiter.respond_to?(:to_sym)
                       record.send(delimiter)
                     else
                       delimiter
                     end

        exclusions.send(inclusion_method(exclusions), value)
      end

      def delimiter
        @delimiter ||= options[:in] || options[:within]
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
