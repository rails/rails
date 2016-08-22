module ActiveRecord
  module Type
    class Value # :nodoc:
      attr_reader :precision, :scale, :limit

      # Valid options are +precision+, +scale+, and +limit+. They are only
      # used when dumping schema.
      def initialize(options = {})
        options.assert_valid_keys(:precision, :scale, :limit)
        @precision = options[:precision]
        @scale = options[:scale]
        @limit = options[:limit]
      end

      # The simplified type that this object represents. Returns a symbol such
      # as +:string+ or +:integer+
      def type; end

      # Type casts a string from the database into the appropriate ruby type.
      # Classes which do not need separate type casting behavior for database
      # and user provided values should override +cast_value+ instead.
      def type_cast_from_database(value)
        type_cast(value)
      end

      # Type casts a value from user input (e.g. from a setter). This value may
      # be a string from the form builder, or an already type cast value
      # provided manually to a setter.
      #
      # Classes which do not need separate type casting behavior for database
      # and user provided values should override +type_cast+ or +cast_value+
      # instead.
      def type_cast_from_user(value)
        type_cast(value)
      end

      # Cast a value from the ruby type to a type that the database knows how
      # to understand. The returned value from this method should be a
      # +String+, +Numeric+, +Date+, +Time+, +Symbol+, +true+, +false+, or
      # +nil+
      def type_cast_for_database(value)
        value
      end

      # Type cast a value for schema dumping. This method is private, as we are
      # hoping to remove it entirely.
      def type_cast_for_schema(value) # :nodoc:
        value.inspect
      end

      # These predicates are not documented, as I need to look further into
      # their use, and see if they can be removed entirely.
      def text? # :nodoc:
        false
      end

      def number? # :nodoc:
        false
      end

      def binary? # :nodoc:
        false
      end

      def klass # :nodoc:
      end

      # Determines whether a value has changed for dirty checking. +old_value+
      # and +new_value+ will always be type-cast. Types should not need to
      # override this method.
      def changed?(old_value, new_value, _new_value_before_type_cast)
        old_value != new_value
      end

      # Determines whether the mutable value has been modified since it was
      # read. Returns +false+ by default. This method should not be overridden
      # directly. Types which return a mutable value should include
      # +Type::Mutable+, which will define this method.
      def changed_in_place?(*)
        false
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

      private

      def type_cast(value)
        cast_value(value) unless value.nil?
      end

      # Convenience method for types which do not need separate type casting
      # behavior for user and database inputs. Called by
      # `type_cast_from_database` and `type_cast_from_user` for all values
      # except `nil`.
      def cast_value(value) # :doc:
        value
      end
    end
  end
end
