require "active_support/core_ext/class/attribute"
require "active_support/core_ext/string/inflections"
require "set"

module ActiveModel
  class Serializer
    class_attribute :_attributes
    self._attributes = Set.new

    class_attribute :_associations
    self._associations = {}

    class << self
      def attributes(*attrs)
        self._attributes += attrs
      end

      def has_many(*attrs)
        options = attrs.extract_options!
        options[:has_many] = true
        hash = {}
        attrs.each { |attr| hash[attr] = options }
        self._associations = _associations.merge(hash)
      end

      def has_one(*attrs)
        options = attrs.extract_options!
        options[:has_one] = true
        hash = {}
        attrs.each { |attr| hash[attr] = options }
        self._associations = _associations.merge(hash)
      end

      def inherited(klass)
        name = klass.name.demodulize.underscore.sub(/_serializer$/, '')

        klass.class_eval do
          alias_method name.to_sym, :object
        end
      end
    end

    attr_reader :object, :scope

    def initialize(object, scope)
      @object, @scope = object, scope
    end

    def as_json(*)
      serializable_hash
    end

    def serializable_hash
      hash = attributes

      _associations.each do |association, options|
        associated_object = object.send(association)
        serializer = options[:serializer]

        if options[:has_many]
          serialized_array = associated_object.map do |item|
            serializer.new(item, scope).serializable_hash
          end

          hash[association] = serialized_array
        elsif options[:has_one]
          hash[association] = serializer.new(associated_object, scope).serializable_hash
        end
      end

      hash
    end

    def attributes
      hash = {}

      _attributes.each do |name|
        hash[name] = @object.read_attribute_for_serialization(name)
      end

      hash
    end
  end
end
