# frozen_string_literal: true

module ActiveRecord
  module Type
    class Time < ActiveModel::Type::Time
      include Internal::Timezone

      class Value < DelegateClass(::Time) # :nodoc:
        def encode_with(coder)
          case self.__getobj__
          when ::Time
            # Time here means we won't be able to
            # delegate the serialization to TWZ so we need to
            # do it ourself
            time_zone = ::Time.find_zone(self.__getobj__.zone)
            utc = self.__getobj__.utc
            time = self.__getobj__
            ActiveSupport::TimeWithZone.new(utc, time_zone, time).encode_with(coder)
#            coder.map = { "utc" => utc, "zone" => time_zone, "time" => time }
          else
            self.__getobj__.encode_with(coder)
          end
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
::YAML.dump_tags[ActiveRecord::Type::Time::Value] = "!ruby/object:ActiveSupport::TimeWithZone"
::YAML.load_tags['!ruby/object:ActiveRecord::Type::Time::Value'] = 'ActiveSupport::TimeWithZone'
