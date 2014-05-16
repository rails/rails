module ActiveRecord::ConnectionAdapters::Type
  class Integer < Value
    include Numeric

    def type
      :integer
    end

    def klass
      ::Fixnum
    end

    private

    def cast_value(value)
      case value
      when ::TrueClass, ::FalseClass
        value ? 1 : 0
      else
        value.to_i rescue nil
      end
    end
  end
end
