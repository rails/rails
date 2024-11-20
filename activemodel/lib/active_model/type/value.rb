# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \Value \Type
    #
    # The base class for all attribute types. This class also serves as the
    # default type for attributes that do not specify a type.
    class Value
      include SerializeCastValue
      attr_reader :precision, :scale, :limit

      # Initializes a type with three basic configuration settings: precision,
      # limit, and scale. The Value base class does not define behavior for
      # these settings. It uses them for equality comparison and hash key
      # generation only.
      def initialize(precision: nil, limit: nil, scale: nil)
        super()
        @precision = precision
        @scale = scale
        @limit = limit
      end

      # Returns true if this type can convert +value+ to a type that is usable
      # by the database.  For example a boolean type can return +true+ if the
      # value parameter is a Ruby boolean, but may return +false+ if the value
      # parameter is some other object.
      def serializable?(value)
        true
      end

      # Returns the unique type name as a Symbol. Subclasses should override
      # this method.
      def type
      end

      # Converts a value from database input to the appropriate ruby type. The
      # return value of this method will be returned from
      # ActiveRecord::AttributeMethods::Read#read_attribute. The default
      # implementation just calls Value#cast.
      #
      # +value+ The raw input, as provided from the database.
      def deserialize(value)
        cast(value)
      end

      # Type casts a value from user input (e.g. from a setter). This value may
      # be a string from the form builder, or a ruby object passed to a setter.
      # There is currently no way to differentiate between which source it came
      # from.
      #
      # The return value of this method will be returned from
      # ActiveRecord::AttributeMethods::Read#read_attribute. See also:
      # Value#cast_value.
      #
      # +value+ The raw input, as provided to the attribute setter.
      def cast(value)
        cast_value(value) unless value.nil?
      end

      # Casts a value from the ruby type to a type that the database knows how
      # to understand. The returned value from this method should be a
      # +String+, +Numeric+, +Date+, +Time+, +Symbol+, +true+, +false+, or
      # +nil+.
      def serialize(value)
        value
      end

      # Type casts a value for schema dumping. This method is private, as we are
      # hoping to remove it entirely.
      def type_cast_for_schema(value) # :nodoc:
        value.inspect
      end

      # These predicates are not documented, as I need to look further into
      # their use, and see if they can be removed entirely.
      def binary? # :nodoc:
        false
      end

      # Determines whether a value has changed for dirty checking. +old_value+
      # and +new_value+ will always be type-cast. Types should not need to
      # override this method.
      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value != new_value
      end

      # Determines whether the mutable value has been modified since it was
      # read. Returns +false+ by default. If your type returns an object
      # which could be mutated, you should override this method. You will need
      # to either:
      #
      # - pass +new_value+ to Value#serialize and compare it to
      #   +raw_old_value+
      #
      # or
      #
      # - pass +raw_old_value+ to Value#deserialize and compare it to
      #   +new_value+
      #
      # +raw_old_value+ The original value, before being passed to
      # +deserialize+.
      #
      # +new_value+ The current value, after type casting.
      def changed_in_place?(raw_old_value, new_value)
        false
      end

      def value_constructed_by_mass_assignment?(_value) # :nodoc:
        false
      end

      def force_equality?(_value) # :nodoc:
        false
      end

      def map(value, &) # :nodoc:
        value
      end

      def ==(other)
        self.class == other.class &&
          precision == other.precision &&
          scale == other.scale &&
          limit == other.limit
      end
      alias eql? ==

      def hash
        [self.class, precision, scale, limit].hash
      end

      def assert_valid_value(_)
      end

      def serialized? # :nodoc:
        false
      end

      def mutable? # :nodoc:
        false
      end

      def as_json(*)
        raise NoMethodError
      end

      private
        # Convenience method for types which do not need separate type casting
        # behavior for user and database inputs. Called by Value#cast for
        # values except +nil+.
        def cast_value(value) # :doc:
          value
        end
    end
  end
end
