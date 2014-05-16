module ActiveRecord::ConnectionAdapters::Type
  class Float < Value
    include Numeric

    def type
      :float
    end

    def klass
      ::Float
    end

    private

    def cast_value(value)
      value.to_f
    end
  end
end
