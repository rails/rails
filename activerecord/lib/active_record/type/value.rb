module ActiveRecord
  module Type
    class Value # :nodoc:
      attr_reader :precision, :scale, :limit

      # Valid options are +precision+, +scale+, and +limit+.
      # They are only used when dumping schema.
      def initialize(options = {})
        options.assert_valid_keys(:precision, :scale, :limit)
        @precision = options[:precision]
        @scale = options[:scale]
        @limit = options[:limit]
      end

      # The simplified type that this object represents. Subclasses
      # must override this method.
      def type; end

      # Takes an input from the database, or from attribute setters,
      # and casts it to a type appropriate for this object. This method
      # should not be overriden by subclasses. Instead, override `cast_value`.
      def type_cast(value)
        cast_value(value) unless value.nil?
      end

      def type_cast_for_database(value)
        type_cast_for_write(value)
      end

      def type_cast_for_schema(value)
        value.inspect
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

      def serialized?
        false
      end

      def klass # :nodoc:
        ::Object
      end

      def type_cast_for_write(value) # :nodoc:
        value
      end

      # +old_value+ will always be type-cast.
      # +new_value+ will come straight from the database
      # or from assignment, so it could be anything. Types
      # which cannot typecast arbitrary values should override
      # this method.
      def changed?(old_value, new_value) # :nodoc:
        old_value != type_cast(new_value)
      end

      private

      # Responsible for casting values from external sources to the appropriate
      # type. Called by `type_cast` for all values except `nil`.
      def cast_value(value) # :api: public
        value
      end
    end
  end
end
