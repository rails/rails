module ActiveRecord::ConnectionAdapters::Type
  class Boolean < Value
    def type
      :boolean
    end

    def klass
      ::Object
    end

    private

    def cast_value(value)
      if ::String === value && value.empty?
        nil
      else
        ActiveRecord::ConnectionAdapters::Column::TRUE_VALUES.include?(value)
      end
    end
  end
end
