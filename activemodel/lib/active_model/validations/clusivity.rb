# frozen_string_literal: true

require "active_support/core_ext/range"

module ActiveModel
  module Validations
    module Clusivity #:nodoc:
      ERROR_MESSAGE = "An object with the method #include? or a proc, lambda or symbol is required, " \
                      "and must be supplied as the :in (or :within) option of the configuration hash"

      def check_validity!
        unless delimiter.respond_to?(:include?) || delimiter.respond_to?(:call) || delimiter.respond_to?(:to_sym)
          raise ArgumentError, ERROR_MESSAGE
        end
      end

    private

      def include?(record, value)
        members = if delimiter.respond_to?(:call)
          delimiter.call(record)
        elsif delimiter.respond_to?(:to_sym)
          record.send(delimiter)
        else
          delimiter
        end

        members.send(inclusion_method(members), value)
      end

      def delimiter
        @delimiter ||= options[:in] || options[:within]
      end

      # In Ruby 2.2 <tt>Range#include?</tt> on non-number-or-time-ish ranges checks all
      # possible values in the range for equality, which is slower but more accurate.
      # <tt>Range#cover?</tt> uses the previous logic of comparing a value with the range
      # endpoints, which is fast but is only accurate on Numeric, Time, Date,
      # or DateTime ranges.
      def inclusion_method(enumerable)
        if enumerable.is_a? Range
          case enumerable.first
          when Numeric, Time, DateTime, Date
            :cover?
          else
            :include?
          end
        else
          :include?
        end
      end
    end
  end
end
