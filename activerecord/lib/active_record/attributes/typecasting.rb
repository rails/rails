module ActiveRecord
  module Attributes
    module Typecasting
      # Typecasts values during access based on their key mapping to a Type.
      #
      # Example:
      # class Attributes < Hash
      #   include Typecasting
      # end
      #
      # attributes = Attributes.new
      # attributes.types['comments_count'] = Type::Integer
      # attributes['comments_count'] = '5'
      #
      # attributes['comments_count']
      # => 5
      #
      # To support keys not mapped to a typecaster, add a default to types.
      # attributes.types.default = Type::Unknown
      # attributes['age'] = '25'
      # attributes['age']
      # => '25'
      #
      # A valid type supports #cast, #precast, #boolean, and #appendable? methods.
      #
      def [](key)
        value = super(key)
        typecast_read(key, value)
      end

      def []=(key, value)
        super(key, typecast_write(key, value))
      end

      def to_h
        hash = {}
        hash.merge!(self)
        hash
      end
      
      def dup # :nodoc:
        copy = super
        copy.types = types.dup
        copy
      end

      # Provides a duplicate with typecasting disabled.
      #
      # Example:
      # attributes = Attributes.new
      # attributes.types['comments_count'] = Type::Integer
      # attributes['comments_count'] = '5'
      #
      # attributes.without_typecast['comments_count']
      # => '5'
      #
      def without_typecast
        dup.without_typecast!
      end

      def without_typecast!
        types.clear
        self
      end

      def typecast!
        keys.each { |key| self[key] = self[key] }
        self
      end

      # Check if key has a value that typecasts to true.
      #
      # attributes = Attributes.new
      # attributes.types['comments_count'] = Type::Integer
      #
      # attributes['comments_count'] = 0
      # attributes.has?('comments_count')
      # => false
      #
      # attributes['comments_count'] = 1
      # attributes.has?('comments_count')
      # => true
      #
      def has?(key)
        value = self[key]
        boolean_typecast(key, value)
      end

      def types
        @types ||= {}
      end

      protected

      def types=(other_types)
        @types = other_types
      end

      def boolean_typecast(key, value)
        value ? types[key].boolean(value) : false
      end

      def typecast_read(key, value)
        type  = types[key]
        value = type.cast(value)
        self[key] = value if type.appendable? && !frozen?

        value
      end

      def typecast_write(key, value)
        types[key].precast(value)
      end

    end
  end
end
