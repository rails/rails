require 'active_record/attribute_set/builder'
require 'active_record/attribute_set/yaml_encoder'

module ActiveRecord
  class AttributeSet # :nodoc:
    delegate :each_value, :fetch, to: :attributes

    def initialize(attributes)
      @attributes = attributes
    end

    def [](name)
      attributes[name] || Attribute.null(name)
    end

    def []=(name, value)
      attributes[name] = value
    end

    def values_before_type_cast
      attributes.transform_values(&:value_before_type_cast)
    end

    def to_hash
      initialized_attributes.transform_values(&:value)
    end
    alias_method :to_h, :to_hash

    def key?(name)
      attributes.key?(name) && self[name].initialized?
    end

    def keys
      attributes.each_key.select { |name| self[name].initialized? }
    end

    if defined?(JRUBY_VERSION)
      # This form is significantly faster on JRuby, and this is one of our biggest hotspots.
      # https://github.com/jruby/jruby/pull/2562
      def fetch_value(name, &block)
        self[name].value(&block)
      end
    else
      def fetch_value(name)
        self[name].value { |n| yield n if block_given? }
      end
    end

    def write_from_database(name, value)
      attributes[name] = self[name].with_value_from_database(value)
    end

    def write_from_user(name, value)
      attributes[name] = self[name].with_value_from_user(value)
    end

    def write_cast_value(name, value)
      attributes[name] = self[name].with_cast_value(value)
    end

    def freeze
      @attributes.freeze
      super
    end

    def deep_dup
      dup.tap do |copy|
        copy.instance_variable_set(:@attributes, attributes.deep_dup)
      end
    end

    def initialize_dup(_)
      @attributes = attributes.dup
      super
    end

    def initialize_clone(_)
      @attributes = attributes.clone
      super
    end

    def reset(key)
      if key?(key)
        write_from_database(key, nil)
      end
    end

    def accessed
      attributes.select { |_, attr| attr.has_been_read? }.keys
    end

    def map(&block)
      new_attributes = attributes.transform_values(&block)
      AttributeSet.new(new_attributes)
    end

    def ==(other)
      attributes == other.attributes
    end

    protected

    attr_reader :attributes

    private

    def initialized_attributes
      attributes.select { |_, attr| attr.initialized? }
    end
  end
end
