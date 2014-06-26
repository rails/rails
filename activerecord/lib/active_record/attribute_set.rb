module ActiveRecord
  class AttributeSet # :nodoc:
    delegate :[], :[]=, :fetch, :include?, :keys, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def values_before_type_cast
      attributes.each_with_object({}) { |(k, v), h| h[k] = v.value_before_type_cast }
    end

    def to_hash
      attributes.each_with_object({}) { |(k, v), h| h[k] = v.value }
    end
    alias_method :to_h, :to_hash

    def freeze
      @attributes.freeze
      super
    end

    def initialize_dup(_)
      @attributes = attributes.dup
      attributes.each do |key, attr|
        attributes[key] = attr.dup
      end

      super
    end

    def initialize_clone(_)
      @attributes = attributes.clone
      super
    end

    class Builder # :nodoc:
      def initialize(types)
        @types = types
      end

      def build_from_database(values, additional_types = {})
        attributes = Hash.new(Attribute::Null)
        values.each_with_object(attributes) do |(name, value), hash|
          type = additional_types.fetch(name, @types[name])
          hash[name] = Attribute.from_database(value, type)
        end
        AttributeSet.new(attributes)
      end
    end

    protected

    attr_reader :attributes
  end
end
