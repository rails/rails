# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Date \Type
    #
    # Attribute type for date representation. It is registered under the
    # +:date+ key.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :birthday, :date
    #   end
    #
    #   person = Person.new
    #   person.birthday = "1989-07-13"
    #
    #   person.birthday.class # => Date
    #   person.birthday.year  # => 1989
    #   person.birthday.month # => 7
    #   person.birthday.day   # => 13
    #
    # String values are parsed using the ISO 8601 date format. Any other values
    # are cast using their +to_date+ method, if it exists.
    class Date < Value
      include Helpers::Timezone
      include Helpers::AcceptsMultiparameterTime.new

      def type
        :date
      end

      def type_cast_for_schema(value)
        value.to_fs(:db).inspect
      end

      private
        def cast_value(value)
          if value.is_a?(::String)
            return if value.empty?
            fast_string_to_date(value) || fallback_string_to_date(value)
          elsif value.respond_to?(:to_date)
            value.to_date
          else
            value
          end
        end

        ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
        def fast_string_to_date(string)
          if string =~ ISO_DATE
            new_date $1.to_i, $2.to_i, $3.to_i
          end
        end

        def fallback_string_to_date(string)
          parts = begin
            ::Date._parse(string, false)
          rescue ArgumentError
          end

          new_date(*parts.values_at(:year, :mon, :mday)) if parts
        end

        def new_date(year, mon, mday)
          unless year.nil? || (year == 0 && mon == 0 && mday == 0)
            ::Date.new(year, mon, mday) rescue nil
          end
        end

        def value_from_multiparameter_assignment(*)
          time = super
          time && new_date(time.year, time.mon, time.mday)
        end
    end
  end
end
