require "active_support/core_ext/class/attribute"
require "active_support/core_ext/string/inflections"
require "set"

module ActiveModel
  class Serializer
    class_attribute :_attributes
    self._attributes = Set.new

    def self.attributes(*attrs)
      self._attributes += attrs
    end

    attr_reader :object, :scope

    def self.inherited(klass)
      name = klass.name.demodulize.underscore.sub(/_serializer$/, '')

      klass.class_eval do
        alias_method name.to_sym, :object
      end
    end

    def initialize(object, scope)
      @object, @scope = object, scope
    end

    def as_json(*)
      serializable_hash
    end

    def serializable_hash(*)
      attributes
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
