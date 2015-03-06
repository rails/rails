module ActiveRecord
  module Type
    class TypedStore < DelegateClass(Type::Value) # :nodoc:
      # Creates +TypedStore+ type instance and specifies type caster
      # for key.
      def self.create_from_type(basetype, key, type, **options)
        typed_store = new(basetype)
        typed_store.add_typed_key(key, type, **options)
        typed_store
      end

      def initialize(subtype)
        @accessor_types = {}
        @store_accessor = subtype.accessor
        super(subtype)
      end

      def add_typed_key(key, type, **options)
        if type.is_a?(Symbol)
          type = ActiveRecord::Type.lookup(type, options)
        end
        @accessor_types[key.to_s] = type
      end

      def deserialize(value)
        hash = super
        cast(hash)
      end

      def serialize(value)
        if value
          accessor_types.each do |key, type|
            k = key_to_cast(value, key)
            value[k] = type.serialize(value[k]) unless k.nil?
          end
        end
        super(value)
      end

      def cast(value)
        hash = super
        if hash
          accessor_types.each do |key, type|
            hash[key] = type.cast(hash[key]) if hash.key?(key)
          end
        end
        hash
      end

      def accessor
        self
      end

      def write(object, attribute, key, value)
        if typed?(key)
          value = type_for(key).cast(value)
        end
        store_accessor.write(object, attribute, key, value)
      end

      delegate :read, :prepare, to: :store_accessor

      protected
        # We cannot rely on string keys 'cause user input can contain symbol keys
        def key_to_cast(val, key)
          return key if val.key?(key)
          return key.to_sym if val.key?(key.to_sym)
        end

        def typed?(key)
          accessor_types.key?(key.to_s)
        end

        def type_for(key)
          accessor_types.fetch(key.to_s)
        end

        attr_reader :accessor_types, :store_accessor
    end
  end
end
