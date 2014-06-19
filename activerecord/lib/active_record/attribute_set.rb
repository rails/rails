module ActiveRecord
  class AttributeSet # :nodoc:
    delegate :[], :[]=, :fetch, :include?, :keys, :each_with_object, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def update(other)
      attributes.update(other.attributes)
    end

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

    class Builder
      def initialize(types)
        @types = types
      end

      def build_from_database(values, additional_types = {})
        attributes = values.each_with_object({}) do |(name, value), hash|
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
