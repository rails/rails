module ActiveRecord
  class Attribute # :nodoc:
    class << self
      def from_database(value, type)
        FromDatabase.new(value, type)
      end

      def from_user(value, type)
        FromUser.new(value, type)
      end
    end

    attr_reader :value_before_type_cast, :type

    # This method should not be called directly.
    # Use #from_database or #from_user
    def initialize(value_before_type_cast, type)
      @value_before_type_cast = value_before_type_cast
      @type = type
    end

    def value
      # `defined?` is cheaper than `||=` when we get back falsy values
      @value = type_cast(value_before_type_cast) unless defined?(@value)
      @value
    end

    def value_for_database
      type.type_cast_for_database(value)
    end

    def type_cast
      raise NotImplementedError
    end

    protected

    def initialize_dup(other)
      if defined?(@value) && @value.duplicable?
        @value = @value.dup
      end
    end

    class FromDatabase < Attribute
      def type_cast(value)
        type.type_cast_from_database(value)
      end
    end

    class FromUser < Attribute
      def type_cast(value)
        type.type_cast_from_user(value)
      end
    end
  end
end
