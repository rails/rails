module ActiveRecord::ConnectionAdapters::Type
  class Value
    def type; end

    def type_cast(value)
      return if value.nil?
      cast_value(value)
    end

    def type_cast_for_write(value)
      value
    end

    def text?
      false
    end

    def number?
      false
    end

    def binary?
      false
    end

    def infinity(options = {})
      ::Float::INFINITY * (options[:negative] ? -1 : 1)
    end

    private

    def cast_value(value)
      value
    end
  end
end
