# frozen_string_literal: true

module ActiveModel
  module Type
    # = Active Model \ImmutableString \Type
    #
    # Attribute type to represent immutable strings. It casts incoming values to
    # frozen strings.
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :name, :immutable_string
    #   end
    #
    #   person = Person.new
    #   person.name = 1
    #
    #   person.name # => "1"
    #   person.name.frozen? # => true
    #
    # Values are coerced to strings using their +to_s+ method. Boolean values
    # are treated differently, however: +true+ will be cast to <tt>"t"</tt> and
    # +false+ will be cast to <tt>"f"</tt>. These strings can be customized when
    # declaring an attribute:
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :active, :immutable_string, true: "aye", false: "nay"
    #   end
    #
    #   person = Person.new
    #   person.active = true
    #
    #   person.active # => "aye"
    #
    # The +limit+ option can be used to ensure the string is limited
    # to the specified number of characters:
    #
    #   class Person
    #     include ActiveModel::Attributes
    #
    #     attribute :code, :immutable_string, limit: 3
    #   end
    #
    #   person = Person.new
    #   person.code = "foobar"
    #   person.code # => "foo"
    class ImmutableString < Value
      def initialize(**args)
        @true  = -(args.delete(:true)&.to_s  || "t")
        @false = -(args.delete(:false)&.to_s || "f")
        super
      end

      def type
        :string
      end

      def serialize(value)
        limited_value(to_str(value))
      end

      def serialize_cast_value(value) # :nodoc:
        value
      end

      private
        def to_str(value)
          case value
          when ::Numeric, ::Symbol, ActiveSupport::Duration then value.to_s
          when true then @true
          when false then @false
          else value end
        end

        def cast_value(value)
          limited_value(to_str(value))
        end

        def limited_value(value)
          if @limit.present?
            value[0, @limit]
          else
            value
          end
        end
    end
  end
end
