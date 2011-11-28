require "active_support/core_ext/class/attribute"
require "active_support/core_ext/string/inflections"
require "active_support/core_ext/module/anonymous"
require "set"

module ActiveModel
  # Active Model Array Serializer
  #
  # It serializes an array checking if each element that implements
  # the +active_model_serializer+ method passing down the current scope.
  class ArraySerializer
    attr_reader :object, :scope

    def initialize(object, scope)
      @object, @scope = object, scope
    end

    def serializable_array
      @object.map do |item|
        if item.respond_to?(:active_model_serializer) && (serializer = item.active_model_serializer)
          serializer.new(item, scope)
        else
          item
        end
      end
    end

    def as_json(*args)
      serializable_array.as_json(*args)
    end
  end

  # Active Model Serializer
  #
  # Provides a basic serializer implementation that allows you to easily
  # control how a given object is going to be serialized. On initialization,
  # it expects to object as arguments, a resource and a scope. For example,
  # one may do in a controller:
  #
  #     PostSerializer.new(@post, current_user).to_json
  #
  # The object to be serialized is the +@post+ and the scope is +current_user+.
  #
  # We use the scope to check if a given attribute should be serialized or not.
  # For example, some attributes maybe only be returned if +current_user+ is the
  # author of the post:
  #
  #     class PostSerializer < ActiveModel::Serializer
  #       attributes :title, :body
  #       has_many :comments
  #     
  #       private
  #
  #       def attributes
  #         hash = super
  #         hash.merge!(:email => post.email) if author?
  #         hash
  #       end
  #     
  #       def author?
  #         post.author == scope
  #       end
  #     end
  #
  class Serializer
    module Associations #:nodoc:
      class Config < Struct.new(:name, :options) #:nodoc:
        def serializer
          options[:serializer]
        end
      end

      class HasMany < Config #:nodoc:
        def serialize(collection, scope)
          collection.map do |item|
            serializer.new(item, scope).serializable_hash
          end
        end

        def serialize_ids(collection, scope)
          # use named scopes if they are present
          # return collection.ids if collection.respond_to?(:ids)

          collection.map do |item|
            item.read_attribute_for_serialization(:id)
          end
        end
      end

      class HasOne < Config #:nodoc:
        def serialize(object, scope)
          object && serializer.new(object, scope).serializable_hash
        end

        def serialize_ids(object, scope)
          object && object.read_attribute_for_serialization(:id)
        end
      end
    end

    class_attribute :_attributes
    self._attributes = Set.new

    class_attribute :_associations
    self._associations = []

    class_attribute :_root
    class_attribute :_embed
    self._embed = :objects
    class_attribute :_root_embed

    class << self
      # Define attributes to be used in the serialization.
      def attributes(*attrs)
        self._attributes += attrs
      end

      def associate(klass, attrs) #:nodoc:
        options = attrs.extract_options!
        self._associations += attrs.map do |attr|
          unless method_defined?(attr)
            class_eval "def #{attr}() object.#{attr} end", __FILE__, __LINE__
          end

          options[:serializer] ||= const_get("#{attr.to_s.camelize}Serializer")
          klass.new(attr, options)
        end
      end

      # Defines an association in the object should be rendered.
      #
      # The serializer object should implement the association name
      # as a method which should return an array when invoked. If a method
      # with the association name does not exist, the association name is
      # dispatched to the serialized object.
      def has_many(*attrs)
        associate(Associations::HasMany, attrs)
      end

      # Defines an association in the object should be rendered.
      #
      # The serializer object should implement the association name
      # as a method which should return an object when invoked. If a method
      # with the association name does not exist, the association name is
      # dispatched to the serialized object.
      def has_one(*attrs)
        associate(Associations::HasOne, attrs)
      end

      # Define how associations should be embedded.
      #
      #   embed :objects               # Embed associations as full objects
      #   embed :ids                   # Embed only the association ids
      #   embed :ids, :include => true # Embed the association ids and include objects in the root
      #
      def embed(type, options={})
        self._embed = type
        self._root_embed = true if options[:include]
      end

      # Defines the root used on serialization. If false, disables the root.
      def root(name)
        self._root = name
      end

      def inherited(klass) #:nodoc:
        return if klass.anonymous?

        name = klass.name.demodulize.underscore.sub(/_serializer$/, '')

        klass.class_eval do
          alias_method name.to_sym, :object
          root name.to_sym unless self._root == false
        end
      end
    end

    attr_reader :object, :scope

    def initialize(object, scope)
      @object, @scope = object, scope
    end

    # Returns a json representation of the serializable
    # object including the root.
    def as_json(*)
      if _root
        hash = { _root => serializable_hash }
        hash.merge!(associations) if _root_embed
        hash
      else
        serializable_hash
      end
    end

    # Returns a hash representation of the serializable
    # object without the root.
    def serializable_hash
      if _embed == :ids
        attributes.merge(association_ids)
      elsif _embed == :objects
        attributes.merge(associations)
      else
        attributes
      end
    end

    # Returns a hash representation of the serializable
    # object associations.
    def associations
      hash = {}

      _associations.each do |association|
        associated_object = send(association.name)
        hash[association.name] = association.serialize(associated_object, scope)
      end

      hash
    end

    # Returns a hash representation of the serializable
    # object associations ids.
    def association_ids
      hash = {}

      _associations.each do |association|
        associated_object = send(association.name)
        hash[association.name] = association.serialize_ids(associated_object, scope)
      end

      hash
    end

    # Returns a hash representation of the serializable
    # object attributes.
    def attributes
      hash = {}

      _attributes.each do |name|
        hash[name] = @object.read_attribute_for_serialization(name)
      end

      hash
    end
  end
end

class Array
  # Array uses ActiveModel::ArraySerializer.
  def active_model_serializer
    ActiveModel::ArraySerializer
  end
end