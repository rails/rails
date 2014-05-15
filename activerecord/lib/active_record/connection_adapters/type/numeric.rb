module ActiveRecord::ConnectionAdapters::Type
  module Numeric
    def number?
      true
    end

    # Typecast boolean and string to appropriate numeric values
    # for the database.
    def type_cast_for_write(value)
      case value
      when ::FalseClass
        0
      when ::TrueClass
        1
      when ::String
        value.presence
      else
        super
      end
    end
  end
end
