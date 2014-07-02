require 'active_record/attribute_set/builder'

module ActiveRecord
  class AttributeSet # :nodoc:
    delegate :keys, to: :initialized_attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def [](name)
      attributes[name] || Attribute.null(name)
    end

    def values_before_type_cast
      attributes.transform_values(&:value_before_type_cast)
    end

    def to_hash
      initialized_attributes.transform_values(&:value)
    end
    alias_method :to_h, :to_hash

    def include?(name)
      attributes.include?(name) && self[name].initialized?
    end

    def fetch_value(name, &block)
      self[name].value(&block)
    end

    def write_from_database(name, value)
      attributes[name] = self[name].with_value_from_database(value)
    end

    def write_from_user(name, value)
      attributes[name] = self[name].with_value_from_user(value)
    end

    def freeze
      @attributes.freeze
      super
    end

    def initialize_dup(_)
      @attributes = attributes.transform_values(&:dup)
      super
    end

    def initialize_clone(_)
      @attributes = attributes.clone
      super
    end

    def reset(key)
      if include?(key)
        write_from_database(key, nil)
      end
    end

    protected

    attr_reader :attributes

    private

    def initialized_attributes
      attributes.select { |_, attr| attr.initialized? }
    end
  end
end
