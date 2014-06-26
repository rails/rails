module ActiveRecord
  class Attribute # :nodoc:
    class << self
      def from_database(value, type)
        FromDatabase.new(value, type)
      end

      def from_user(value, type)
        FromUser.new(value, type)
      end

      def uninitialized(type)
        Uninitialized.new(type)
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

    def changed_from?(old_value)
      type.changed?(old_value, value, value_before_type_cast)
    end

    def changed_in_place_from?(old_value)
      type.changed_in_place?(old_value, value)
    end

    def type_cast
      raise NotImplementedError
    end

    def initialized?
      true
    end

    protected

    def initialize_dup(other)
      if defined?(@value) && @value.duplicable?
        @value = @value.dup
      end
    end

    class FromDatabase < Attribute # :nodoc:
      def type_cast(value)
        type.type_cast_from_database(value)
      end
    end

    class FromUser < Attribute # :nodoc:
      def type_cast(value)
        type.type_cast_from_user(value)
      end
    end

    class Null # :nodoc:
      class << self
        attr_reader :value, :value_before_type_cast, :value_for_database

        def changed_from?(*)
          false
        end
        alias changed_in_place_from? changed_from?

        def initialized?
          true
        end
      end
    end

    class Uninitialized < Attribute # :nodoc:
      def initialize(type)
        super(nil, type)
      end

      def value
        nil
      end
      alias value_for_database value

      def initialized?
        false
      end
    end
  end
end
