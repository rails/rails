module ActiveRecord::ConnectionAdapters::Type
  class String < Value
    def type
      :string
    end

    def klass
      ::String
    end

    def text?
      true
    end

    private

    def cast_value(value)
      case value
      when ::TrueClass; "1"
      when ::FalseClass; "0"
      else
        value.to_s
      end
    end
  end
end
