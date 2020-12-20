# frozen_string_literal: true

module ActiveRecord
  module Type
    class Time < ActiveModel::Type::Time
      include Internal::Timezone

      class Value < DelegateClass(::Time) # :nodoc:
      end

      def serialize(value)
        case value = super
        when ::Time
          Value.new(value)
        else
          value
        end
      end

      private
        def cast_value(value)
          case value = super
          when Value
            value.__getobj__
          else
            value
          end
        end
    end
  end
end
