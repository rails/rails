module ActiveRecord
  class Attribute # :nodoc:
    class << self
      def from_database(name, value, type)
        FromDatabase.new(name, value, type)
      end

      def from_user(name, value, type)
        FromUser.new(name, value, type)
      end

      def with_cast_value(name, value, type)
        WithCastValue.new(name, value, type)
      end

      def null(name)
        Null.new(name)
      end

      def uninitialized(name, type)
        Uninitialized.new(name, type)
      end
    end

    attr_reader :name, :value_before_type_cast, :type

    # This method should not be called directly.
    # Use #from_database or #from_user
    def initialize(name, value_before_type_cast, type)
      @name = name
      @value_before_type_cast = value_before_type_cast
      @type = type
    end

    def value
      # `defined?` is cheaper than `||=` when we get back falsy values
      @value = original_value unless defined?(@value)
      @value
    end

    def original_value
      type_cast(value_before_type_cast)
    end

    def value_for_database
      type.type_cast_for_database(value)
    end

    def changed_from?(old_value)
      type.changed?(old_value, value, value_before_type_cast)
    end

    def changed_in_place_from?(old_value)
      has_been_read? && type.changed_in_place?(old_value, value)
    end

    def with_value_from_user(value)
      self.class.from_user(name, value, type)
    end

    def with_value_from_database(value)
      self.class.from_database(name, value, type)
    end

    def with_cast_value(value)
      self.class.with_cast_value(name, value, type)
    end

    def type_cast(*)
      raise NotImplementedError
    end

    def initialized?
      true
    end

    def came_from_user?
      false
    end

    def ==(other)
      self.class == other.class &&
        name == other.name &&
        value_before_type_cast == other.value_before_type_cast &&
        type == other.type
    end

    protected

    def initialize_dup(other)
      if defined?(@value) && @value.duplicable?
        @value = @value.dup
      end
    end

    private

    def has_been_read?
      defined?(@value)
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

      def came_from_user?
        true
      end
    end

    class WithCastValue < Attribute # :nodoc:
      def type_cast(value)
        value
      end

      def changed_in_place_from?(old_value)
        false
      end
    end

    class Null < Attribute # :nodoc:
      def initialize(name)
        super(name, nil, Type::Value.new)
      end

      def value
        nil
      end

      def with_value_from_database(value)
        raise ActiveModel::MissingAttributeError, "can't write unknown attribute `#{name}`"
      end
      alias_method :with_value_from_user, :with_value_from_database
    end

    class Uninitialized < Attribute # :nodoc:
      def initialize(name, type)
        super(name, nil, type)
      end

      def value
        if block_given?
          yield name
        end
      end

      def value_for_database
      end

      def initialized?
        false
      end
    end
    private_constant :FromDatabase, :FromUser, :Null, :Uninitialized
  end
end
