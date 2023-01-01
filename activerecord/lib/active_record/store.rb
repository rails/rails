# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

module ActiveRecord
  # Store gives you a thin wrapper around serialize for the purpose of storing hashes in a single column.
  # It's like a simple key/value store baked into your record when you don't care about being able to
  # query that store outside the context of a single record.
  #
  # You can then declare accessors to this store that are then accessible just like any other attribute
  # of the model. This is very helpful for easily exposing store keys to a form or elsewhere that's
  # already built around just accessing attributes on the model.
  #
  # Every accessor comes with dirty tracking methods (+key_changed?+, +key_was+ and +key_change+) and
  # methods to access the changes made during the last save (+saved_change_to_key?+, +saved_change_to_key+ and
  # +key_before_last_save+).
  #
  # NOTE: There is no +key_will_change!+ method for accessors, use +store_will_change!+ instead.
  #
  # Make sure that you declare the database column used for the serialized store as a text, so there's
  # plenty of room.
  #
  # You can set custom coder to encode/decode your serialized attributes to/from different formats.
  # JSON, YAML, Marshal are supported out of the box. Generally it can be any wrapper that provides +load+ and +dump+.
  #
  # NOTE: If you are using structured database data types (e.g. PostgreSQL +hstore+/+json+, or MySQL 5.7+
  # +json+) there is no need for the serialization provided by {.store}[rdoc-ref:rdoc-ref:ClassMethods#store].
  # Simply use {.store_accessor}[rdoc-ref:ClassMethods#store_accessor] instead to generate
  # the accessor methods. Be aware that these columns use a string keyed hash and do not allow access
  # using a symbol.
  #
  # NOTE: The default validations with the exception of +uniqueness+ will work.
  # For example, if you want to check for +uniqueness+ with +hstore+ you will
  # need to use a custom validation to handle it.
  #
  # Examples:
  #
  #   class User < ActiveRecord::Base
  #     store :settings, accessors: [ :color, :homepage ], coder: JSON
  #     store :parent, accessors: [ :name ], coder: JSON, prefix: true
  #     store :spouse, accessors: [ :name ], coder: JSON, prefix: :partner
  #     store :settings, accessors: [ :two_factor_auth ], suffix: true
  #     store :settings, accessors: [ :login_retry ], suffix: :config
  #   end
  #
  #   u = User.new(color: 'black', homepage: '37signals.com', parent_name: 'Mary', partner_name: 'Lily')
  #   u.color                          # Accessor stored attribute
  #   u.parent_name                    # Accessor stored attribute with prefix
  #   u.partner_name                   # Accessor stored attribute with custom prefix
  #   u.two_factor_auth_settings       # Accessor stored attribute with suffix
  #   u.login_retry_config             # Accessor stored attribute with custom suffix
  #   u.settings[:country] = 'Denmark' # Any attribute, even if not specified with an accessor
  #
  #   # There is no difference between strings and symbols for accessing custom attributes
  #   u.settings[:country]  # => 'Denmark'
  #   u.settings['country'] # => 'Denmark'
  #
  #   # Dirty tracking
  #   u.color = 'green'
  #   u.color_changed? # => true
  #   u.color_was # => 'black'
  #   u.color_change # => ['black', 'green']
  #
  #   # Add additional accessors to an existing store through store_accessor
  #   class SuperUser < User
  #     store_accessor :settings, :privileges, :servants
  #     store_accessor :parent, :birthday, prefix: true
  #     store_accessor :settings, :secret_question, suffix: :config
  #   end
  #
  # The stored attribute names can be retrieved using {.stored_attributes}[rdoc-ref:rdoc-ref:ClassMethods#stored_attributes].
  #
  #   User.stored_attributes[:settings] # => [:color, :homepage, :two_factor_auth, :login_retry]
  #
  # == Overwriting default accessors
  #
  # All stored values are automatically available through accessors on the Active Record
  # object, but sometimes you want to specialize this behavior. This can be done by overwriting
  # the default accessors (using the same name as the attribute) and calling <tt>super</tt>
  # to actually change things.
  #
  #   class Song < ActiveRecord::Base
  #     # Uses a stored integer to hold the volume adjustment of the song
  #     store :settings, accessors: [:volume_adjustment]
  #
  #     def volume_adjustment=(decibels)
  #       super(decibels.to_i)
  #     end
  #
  #     def volume_adjustment
  #       super.to_i
  #     end
  #   end
  module Store
    extend ActiveSupport::Concern

    included do
      class << self
        attr_accessor :local_stored_attributes
      end
    end

    module ClassMethods
      def store(store_attribute, options = {})
        serialize store_attribute, IndifferentCoder.new(store_attribute, options[:coder])
        store_accessor(store_attribute, options[:accessors], **options.slice(:prefix, :suffix)) if options.has_key? :accessors
      end

      def store_accessor(store_attribute, *keys, prefix: nil, suffix: nil)
        keys = keys.flatten

        accessor_prefix =
          case prefix
          when String, Symbol
            "#{prefix}_"
          when TrueClass
            "#{store_attribute}_"
          else
            ""
          end
        accessor_suffix =
          case suffix
          when String, Symbol
            "_#{suffix}"
          when TrueClass
            "_#{store_attribute}"
          else
            ""
          end

        _store_accessors_module.module_eval do
          keys.each do |key|
            accessor_key = "#{accessor_prefix}#{key}#{accessor_suffix}"

            define_method("#{accessor_key}=") do |value|
              write_store_attribute(store_attribute, key, value)
            end

            define_method(accessor_key) do
              read_store_attribute(store_attribute, key)
            end

            define_method("#{accessor_key}_changed?") do
              return false unless attribute_changed?(store_attribute)
              prev_store, new_store = changes[store_attribute]
              prev_store&.dig(key) != new_store&.dig(key)
            end

            define_method("#{accessor_key}_change") do
              return unless attribute_changed?(store_attribute)
              prev_store, new_store = changes[store_attribute]
              [prev_store&.dig(key), new_store&.dig(key)]
            end

            define_method("#{accessor_key}_was") do
              return unless attribute_changed?(store_attribute)
              prev_store, _new_store = changes[store_attribute]
              prev_store&.dig(key)
            end

            define_method("saved_change_to_#{accessor_key}?") do
              return false unless saved_change_to_attribute?(store_attribute)
              prev_store, new_store = saved_change_to_attribute(store_attribute)
              prev_store&.dig(key) != new_store&.dig(key)
            end

            define_method("saved_change_to_#{accessor_key}") do
              return unless saved_change_to_attribute?(store_attribute)
              prev_store, new_store = saved_change_to_attribute(store_attribute)
              [prev_store&.dig(key), new_store&.dig(key)]
            end

            define_method("#{accessor_key}_before_last_save") do
              return unless saved_change_to_attribute?(store_attribute)
              prev_store, _new_store = saved_change_to_attribute(store_attribute)
              prev_store&.dig(key)
            end
          end
        end

        # assign new store attribute and create new hash to ensure that each class in the hierarchy
        # has its own hash of stored attributes.
        self.local_stored_attributes ||= {}
        self.local_stored_attributes[store_attribute] ||= []
        self.local_stored_attributes[store_attribute] |= keys
      end

      def _store_accessors_module # :nodoc:
        @_store_accessors_module ||= begin
          mod = Module.new
          include mod
          mod
        end
      end

      def stored_attributes
        parent = superclass.respond_to?(:stored_attributes) ? superclass.stored_attributes : {}
        if local_stored_attributes
          parent.merge!(local_stored_attributes) { |k, a, b| a | b }
        end
        parent
      end
    end

    private
      def read_store_attribute(store_attribute, key) # :doc:
        accessor = store_accessor_for(store_attribute)
        accessor.read(self, store_attribute, key)
      end

      def write_store_attribute(store_attribute, key, value) # :doc:
        accessor = store_accessor_for(store_attribute)
        accessor.write(self, store_attribute, key, value)
      end

      def store_accessor_for(store_attribute)
        type_for_attribute(store_attribute).accessor
      end

      class HashAccessor # :nodoc:
        def self.read(object, attribute, key)
          prepare(object, attribute)
          object.public_send(attribute)[key]
        end

        def self.write(object, attribute, key, value)
          prepare(object, attribute)
          if value != read(object, attribute, key)
            object.public_send :"#{attribute}_will_change!"
            object.public_send(attribute)[key] = value
          end
        end

        def self.prepare(object, attribute)
          object.public_send :"#{attribute}=", {} unless object.send(attribute)
        end
      end

      class StringKeyedHashAccessor < HashAccessor # :nodoc:
        def self.read(object, attribute, key)
          super object, attribute, key.to_s
        end

        def self.write(object, attribute, key, value)
          super object, attribute, key.to_s, value
        end
      end

      class IndifferentHashAccessor < ActiveRecord::Store::HashAccessor # :nodoc:
        def self.prepare(object, store_attribute)
          attribute = object.send(store_attribute)
          unless attribute.is_a?(ActiveSupport::HashWithIndifferentAccess)
            attribute = IndifferentCoder.as_indifferent_hash(attribute)
            object.public_send :"#{store_attribute}=", attribute
          end
          attribute
        end
      end

      class IndifferentCoder # :nodoc:
        def initialize(attr_name, coder_or_class_name)
          @coder =
            if coder_or_class_name.respond_to?(:load) && coder_or_class_name.respond_to?(:dump)
              coder_or_class_name
            else
              ActiveRecord::Coders::YAMLColumn.new(attr_name, coder_or_class_name || Object)
            end
        end

        def dump(obj)
          @coder.dump as_regular_hash(obj)
        end

        def load(yaml)
          self.class.as_indifferent_hash(@coder.load(yaml || ""))
        end

        def self.as_indifferent_hash(obj)
          case obj
          when ActiveSupport::HashWithIndifferentAccess
            obj
          when Hash
            obj.with_indifferent_access
          else
            ActiveSupport::HashWithIndifferentAccess.new
          end
        end

        private
          def as_regular_hash(obj)
            obj.respond_to?(:to_hash) ? obj.to_hash : {}
          end
      end
  end
end
