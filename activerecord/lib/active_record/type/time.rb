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
    end
  end
end

