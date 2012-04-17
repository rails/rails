require 'active_support/core_ext/range.rb'

module ActiveModel
  module Validations
    module Clusivity
      ERROR_MESSAGE = "An object with the method #include? or a proc or lambda is required, " <<
                      "and must be supplied as the :in option of the configuration hash"

      def check_validity!
        unless [:include?, :call].any?{ |method| options[:in].respond_to?(method) }
          raise ArgumentError, ERROR_MESSAGE
        end
      end

    private

      def include?(record, value)
        delimiter = options[:in]
        exclusions = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter
        if exclusions.is_a?(Range)
          exclusions.cover?((Kernel.Float(value) rescue value))
        else
          exclusions.include?(value)
        end
      end
    end
  end
end
