# frozen_string_literal: true

require "active_support/core_ext/object/duplicable"

module ActiveModel
  class Attribute # :nodoc:
    class << self
      def from_database(name, value_before_type_cast, type, value = nil)
        FromDatabase.new(name, value_before_type_cast, type, nil, value)
      end

      def from_user(name, value_before_type_cast, type, original_attribute = nil)
        FromUser.new(name, value_before_type_cast, type, original_attribute)
      end

      def with_cast_value(name, value_before_type_cast, type)
        WithCastValue.new(name, value_before_type_cast, type)
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
    def initialize(name, value_before_type_cast, type, original_attribute = nil, value = nil)
      @name = name
      @value_before_type_cast = value_before_type_cast
      @type = type
      @original_attribute = original_attribute
      @value = value unless value.nil?
    end

    def value
      # `defined?` is cheaper than `||=` when we get back falsy values
      @value = type_cast(value_before_type_cast) unless defined?(@value)
      @value
    end

    def original_value
      if assigned?
        original_attribute.original_value
      else
        type_cast(value_before_type_cast)
      end
    end

    def value_for_database
      if !defined?(@value_for_database) || type.changed_in_place?(@value_for_database, value)
        @value_for_database = _value_for_database
      end
      @value_for_database
    end

    def serializable?(&block)
      type.serializable?(value, &block)
    end

    def changed?
      changed_from_assignment? || changed_in_place?
    end

    def changed_in_place?
      has_been_read? && type.changed_in_place?(original_value_for_database, value)
    end

    def forgetting_assignment
      with_value_from_database(value_for_database)
    end

    def with_value_from_user(value)
      type.assert_valid_value(value)
      self.class.from_user(name, value, type, original_attribute || self)
    end

    def with_value_from_database(value)
      self.class.from_database(name, value, type)
    end

    def with_cast_value(value)
      self.class.with_cast_value(name, value, type)
    end

    def with_type(type)
      if changed_in_place?
        with_value_from_user(value).with_type(type)
      else
        self.class.new(name, value_before_type_cast, type, original_attribute)
      end
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

    def has_been_read?
      defined?(@value)
    end

    def ==(other)
      self.class == other.class &&
        name == other.name &&
        value_before_type_cast == other.value_before_type_cast &&
        type == other.type
    end
    alias eql? ==

    def hash
      [self.class, name, value_before_type_cast, type].hash
    end

    def init_with(coder)
      @name = coder["name"]
      @value_before_type_cast = coder["value_before_type_cast"]
      @type = coder["type"]
      @original_attribute = coder["original_attribute"]
      @value = coder["value"] if coder.map.key?("value")
    end

    def encode_with(coder)
      coder["name"] = name
      coder["value_before_type_cast"] = value_before_type_cast unless value_before_type_cast.nil?
      coder["type"] = type if type
      coder["original_attribute"] = original_attribute if original_attribute
      coder["value"] = value if defined?(@value)
    end

    def original_value_for_database
      if assigned?
        original_attribute.original_value_for_database
      else
        _original_value_for_database
      end
    end

    private
      attr_reader :original_attribute
      alias :assigned? :original_attribute

      def initialize_dup(other)
        if @value&.duplicable?
          @value = @value.dup
        end
      end

      def changed_from_assignment?
        assigned? && type.changed?(original_value, value, value_before_type_cast)
      end

      def _value_for_database
        type.serialize(value)
      end

      def _original_value_for_database
        type.serialize(original_value)
      end

      class FromDatabase < Attribute # :nodoc:
        def type_cast(value)
          type.deserialize(value)
        end

        def forgetting_assignment
          # If this attribute was not persisted (with a `value_for_database`
          # that might differ from `value_before_type_cast`) and `value` has not
          # changed in place, we can use the existing `value_before_type_cast`
          # to avoid deserialize / cast / serialize calls from computing the new
          # attribute's `value_before_type_cast`.
          if !defined?(@value_for_database) && !changed_in_place?
            with_value_from_database(value_before_type_cast)
          else
            super
          end
        end

        private
          def _original_value_for_database
            value_before_type_cast
          end
      end

      class FromUser < Attribute # :nodoc:
        def type_cast(value)
          type.cast(value)
        end

        def came_from_user?
          !type.value_constructed_by_mass_assignment?(value_before_type_cast)
        end

        private
          def _value_for_database
            Type::SerializeCastValue.serialize(type, value)
          end
      end

      class WithCastValue < Attribute # :nodoc:
        def type_cast(value)
          value
        end

        def changed_in_place?
          false
        end
      end

      class Null < Attribute # :nodoc:
        def initialize(name)
          super(name, nil, Type.default_value)
        end

        def type_cast(*)
          nil
        end

        def with_type(type)
          self.class.with_cast_value(name, nil, type)
        end

        def with_value_from_database(value)
          raise ActiveModel::MissingAttributeError, "can't write unknown attribute `#{name}`"
        end
        alias_method :with_value_from_user, :with_value_from_database
        alias_method :with_cast_value, :with_value_from_database
      end

      class Uninitialized < Attribute # :nodoc:
        UNINITIALIZED_ORIGINAL_VALUE = Object.new

        def initialize(name, type)
          super(name, nil, type)
        end

        def value
          if block_given?
            yield name
          end
        end

        def original_value
          UNINITIALIZED_ORIGINAL_VALUE
        end

        def value_for_database
        end

        def initialized?
          false
        end

        def forgetting_assignment
          dup
        end

        def with_type(type)
          self.class.new(name, type)
        end
      end

      private_constant :FromDatabase, :FromUser, :Null, :Uninitialized, :WithCastValue
  end
end
