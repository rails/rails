# frozen_string_literal: true

module ActiveRecord
  module Type
    class Time < ActiveModel::Type::Time
      include Internal::Timezone

      Value = ActiveSupport::Delegation::DelegateClass(::Time) # :nodoc:

      def serialize(value)
        case value = super
        when ::Time
          Value.new(value)
        else
          value
        end
      end

      def serialize_cast_value(value) # :nodoc:
        Value.new(super) if value
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
