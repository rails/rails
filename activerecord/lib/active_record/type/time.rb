# frozen_string_literal: true
module ActiveRecord
  module Type
    class Time < ActiveModel::Type::Time
      include Internal::Timezone

      class Value < DelegateClass(::Time) # :nodoc:
        def init_with(coder) # :nodoc:

          if coder["utc"] && coder["zone"] && coder["time"]
            # legacy data serialized via TimeWithZone
            local_time = coder["zone"].utc_to_local(coder["utc"])

            # TODO: Check this more, worried I might get something else if this method has been overloaded elsewhere
            raise "Something not right" unless ::Time === local_time
            initialize(local_time)
          else
            initialize(coder["value"])
          end

        end

        def encode_with(coder) # :nodoc:
          #      coder.tag = "!ruby/object:ActiveSupport::TimeWithZone"
          coder.map = { "value" => __getobj__ }
        end
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
