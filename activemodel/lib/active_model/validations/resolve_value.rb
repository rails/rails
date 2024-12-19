# frozen_string_literal: true

module ActiveModel
  module Validations
    module ResolveValue # :nodoc:
      def resolve_value(record, value)
        case value
        when ActiveSupport::Callable
          arity = value.respond_to?(:arity) ? value.arity : value.method(:call).arity
          if arity == 0
            value.call
          else
            value.call(record)
          end
        when Symbol
          record.send(value)
        else
          value
        end
      end
    end
  end
end
