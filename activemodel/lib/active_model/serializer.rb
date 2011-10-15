require "active_support/core_ext/class/attribute"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/module/anonymous"
require "set"

module ActiveModel
  class Serializer
    module Associations
      class Config < Struct.new(:name, :options)
        def serializer
          options[:serializer]
        end
      end

      class HasMany < Config
        def serialize(collection, scope)
          collection.map do |item|
            serializer.new(item, scope).serializable_hash
          end
        end
      end

      class HasOne < Config
        def serialize(object, scope)
          serializer.new(object, scope).serializable_hash
        end
      end
    end

    class_attribute :_attributes
    self._attributes = Set.new

    class_attribute :_associations
    self._associations = []

    class << self
      def attributes(*attrs)
        self._attributes += attrs
      end

      def associate(klass, attrs)
        options = attrs.extract_options!
        self._associations += attrs.map do |attr|
          unless method_defined?(attr)
            class_eval "def #{attr}() object.#{attr} end", __FILE__, __LINE__
          end

          options[:serializer] ||= const_get("#{attr.to_s.camelize}Serializer")
          klass.new(attr, options)
        end
      end

      def has_many(*attrs)
        associate(Associations::HasMany, attrs)
      end

      def has_one(*attrs)
        associate(Associations::HasOne, attrs)
      end

      def inherited(klass)
        return if klass.anonymous?

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

      _associations.each do |association|
        associated_object = send(association.name)
        hash[association.name] = association.serialize(associated_object, scope)
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
