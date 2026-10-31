# frozen_string_literal: true

module ActiveModel
  module Validations
    module ResolveValue # :nodoc:
      def resolve_value(record, value)
        case value
        when Proc
          if value.arity == 0
            value.call
          else
            value.call(record)
          end
        when Symbol
          record.send(value)
        else
          if value.respond_to?(:call)
            value.call(record)
          else
            value
          end
        end
      end
    end
  end
end
