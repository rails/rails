# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active \Model \Array \Type
    #
    # Attribute type for array representation. This type is registered under the
    # +:array+ key.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :tags, :array
    #   end
    #
    #   person = Person.new
    #   person.tags = ["ruby", "rails"]
    #   person.tags # => ["ruby", "rails"]
    #
    # The +of+ option can be used to specify the type of array elements:
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :counts, :array, of: :integer
    #     attribute :ratings, :array, of: :decimal, precision: 2
    #   end
    #
    #   person = Person.new
    #   person.counts = ["1", "2", "3"]
    #   person.counts # => [1, 2, 3]
    #
    #   person.ratings = ["3.5", "4.0", "2.5"]
    #   person.ratings # => [3.5, 4.0, 2.5]
    #
    # This type also handles JSON strings for convenient assignment:
    #
    #   person.counts = '[1, 2, 3]'
    #   person.counts # => [1, 2, 3]
    #
    class Array < Value
      include Helpers::Mutable

      # The type of the array elements
      attr_reader :subtype

      # Creates a new Array type
      #
      # ==== Options
      #
      # * <tt>:of</tt> - The type of the array elements. Can be a symbol that
      #   references a registered type or an actual type object. If not provided,
      #   array elements won't be type cast.
      #
      # * <tt>:precision</tt>, <tt>:scale</tt>, <tt>:limit</tt> - Additional options
      #   passed to the element type when <tt>:of</tt> is a symbol.
      def initialize(of: nil, **options)
        if of.is_a?(Symbol)
          subtype_options = options.slice(:precision, :scale, :limit)
          @subtype = Type.lookup(of, **subtype_options)
        else
          @subtype = of
        end

        super(**options.except(:precision, :scale, :limit))
      end

      def type
        :array
      end

      # Casts value to an array. The elements of the resulting array are also type cast
      # if a subtype was specified.
      #
      # ==== Examples
      #
      #   array_type = Type::Array.new
      #   array_type.cast(["1", "2"]) # => ["1", "2"]
      #
      #   int_array_type = Type::Array.new(of: :integer)
      #   int_array_type.cast(["1", "2"]) # => [1, 2]
      #   int_array_type.cast("1") # => [1]
      #   int_array_type.cast('[1, 2]') # => [1, 2]
      def cast(value)
        array_value = cast_to_array(value)
        return if array_value.nil?

        result = if subtype
          array_value.map { |item| cast_element(item) }
        else
          array_value
        end

        # Return a new array to ensure we don't modify the input array
        result.dup
      end

      # Serializes the value as an array. The elements of the array are also serialized
      # if a subtype was specified.
      #
      # ==== Examples
      #
      #   array_type = Type::Array.new
      #   array_type.serialize(["1", "2"]) # => ["1", "2"]
      #
      #   int_array_type = Type::Array.new(of: :integer)
      #   int_array_type.serialize(["1", "2"]) # => [1, 2]
      def serialize(value)
        return if value.nil?

        array_value = cast_to_array(value)
        return array_value unless subtype && array_value

        array_value.map { |item| serialize_element(item) }
      end

      # A key method for ActiveModel::Dirty integration.
      # This helps detect when an array has been modified in place.
      #
      # When an array is modified with methods like #<<, #push, etc.,
      # the object_id stays the same but the content changes. This method
      # compares the serialized representations to detect such changes.
      def changed_in_place?(raw_old_value, new_value)
        return false if raw_old_value.nil?

        # Convert to serialized form for comparison
        old_serialized = serialize(raw_old_value)
        new_serialized = serialize(new_value)

        # Compare serialized forms to detect content changes
        old_serialized != new_serialized
      end

      # Equality comparison
      def ==(other)
        super && subtype == other.subtype
      end
      alias eql? ==

      # Hash method for using this type as a hash key
      def hash
        [super, subtype].hash
      end

      private
        # Cast a value to an array
        def cast_to_array(value)
          case value
          when ::String
            # Return nil for empty strings
            return nil if value.empty?

            # Attempt to parse as JSON
            begin
              decoded = ActiveSupport::JSON.decode(value)
              decoded.is_a?(::Array) ? decoded : [decoded]
            rescue
              # If JSON parsing fails, treat it as a single value
              [value]
            end
          when ::Array
            value
          when nil
            nil
          else
            # Try to convert to array using Array()
            Array(value)
          end
        end

        # Cast a single element using the subtype
        def cast_element(value)
          subtype ? subtype.cast(value) : value
        end

        # Serialize a single element using the subtype
        def serialize_element(value)
          subtype ? subtype.serialize(value) : value
        end
    end
  end
end
