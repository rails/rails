# frozen_string_literal: true

require "active_support/core_ext/hash/indifferent_access"

module ActiveRecord
  # = Active Record \Store
  #
  # Store gives you a thin wrapper around serialize for the purpose of storing hashes in a single column.
  # It's like a simple key/value store baked into your record when you don't care about being able to
  # query that store outside the context of a single record.
  #
  # You can then declare accessors to this store that are then accessible just like any other attribute
  # of the model. This is very helpful for easily exposing store keys to a form or elsewhere that's
  # already built around just accessing attributes on the model.
  #
  # Every accessor comes with the full set of standard attribute methods: a query predicate (+key?+),
  # dirty tracking (+key_changed?+, +key_was+, +key_change+), post-save inspection
  # (+saved_change_to_key?+, +saved_change_to_key+, +key_before_last_save+, +key_previously_changed?+,
  # +key_previous_change+), and pending-change helpers for use in +before_save+ callbacks
  # (+will_save_change_to_key?+, +key_change_to_be_saved+, +key_in_database+).
  #
  # Make sure that you declare the database column used for the serialized store as a text, so there's
  # plenty of room.
  #
  # You can set custom coder to encode/decode your serialized attributes to/from different formats.
  # JSON, YAML, Marshal are supported out of the box. Generally it can be any wrapper that provides +load+ and +dump+.
  #
  # NOTE: If you are using structured database data types (e.g. PostgreSQL +hstore+/+json+, MySQL 5.7+
  # +json+, or SQLite 3.38+ +json+) there is no need for the serialization provided by {.store}[rdoc-ref:rdoc-ref:ClassMethods#store].
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
      def inherited(subclass) # :nodoc:
        super
        subclass.instance_variable_set(:@local_stored_attributes, nil)
      end

      def store(store_name, options = {})
        coder = build_column_serializer(store_name, options[:coder], Object, options[:yaml])
        serialize store_name, coder: IndifferentCoder.new(store_name, coder)
        store_accessor(store_name, options[:accessors], **options.slice(:prefix, :suffix)) if options.has_key? :accessors
      end

      def store_accessor(store_name, *keys, prefix: nil, suffix: nil)
        keys = keys.flatten

        accessor_prefix =
          case prefix
          when String, Symbol
            "#{prefix}_"
          when TrueClass
            "#{store_name}_"
          else
            ""
          end
        accessor_suffix =
          case suffix
          when String, Symbol
            "_#{suffix}"
          when TrueClass
            "_#{store_name}"
          else
            ""
          end

        keys.each do |key|
          accessor_name = "#{accessor_prefix}#{key}#{accessor_suffix}"
          store_attribute(accessor_name, backed_by: store_name, key: key.to_s, definition: StoreAccessorDefinition)
        end

        # assign new store attribute and create new hash to ensure that each class in the hierarchy
        # has its own hash of stored attributes.
        self.local_stored_attributes ||= {}
        self.local_stored_attributes[store_name] ||= []
        self.local_stored_attributes[store_name] |= keys
      end

      def stored_attributes
        parent = superclass.respond_to?(:stored_attributes) ? superclass.stored_attributes : {}
        if local_stored_attributes
          parent.merge!(local_stored_attributes) { |k, a, b| a | b }
        end
        parent
      end
    end

    class StoreAccessorDefinition < ActiveModel::StoreAttribute::Definition # :nodoc:
      def validate!(parent)
        return if parent.type.respond_to?(:accessor)
        raise ConfigurationError, "the column '#{backed_by}' has not been configured as a store. Please make sure the column is declared serializable via 'ActiveRecord.store' or, if your database supports it, use a structured column type like hstore or json."
      end
    end

    private
      def read_store_attribute(store_name, key)
        ActiveRecord.deprecator.warn(<<~MSG)
          `read_store_attribute` is deprecated. Override the accessor and call `super` instead:

              def #{key}
                super&.gsub(...)
              end
        MSG
        accessor = store_accessor_for(store_name)
        accessor.read(self, store_name, key)
      end

      def write_store_attribute(store_name, key, value)
        ActiveRecord.deprecator.warn(<<~MSG)
          `write_store_attribute` is deprecated. Override the accessor and call `super` instead:

              def #{key}=(value)
                super(...)
              end
        MSG
        accessor = store_accessor_for(store_name)
        accessor.write(self, store_name, key, value)
      end

      def store_accessor_for(store_name)
        type_for_attribute(store_name).tap do |type|
          unless type.respond_to?(:accessor)
            raise ConfigurationError, "the column '#{store_name}' has not been configured as a store. Please make sure the column is declared serializable via 'ActiveRecord.store' or, if your database supports it, use a structured column type like hstore or json."
          end
        end.accessor
      end

      class HashAccessor # :nodoc:
        def self.get(store_object, key)
          if store_object
            store_object[key]
          end
        end

        def self.read(object, attribute, key)
          get(object.public_send(attribute), key)
        end

        def self.write(object, attribute, key, value)
          store_object = prepare(object, attribute)
          store_object[key] = value if value != store_object[key]
        end

        def self.prepare(object, attribute)
          store_object = object.public_send(attribute)

          if store_object.nil?
            store_object = {}
            object.public_send(:"#{attribute}=", store_object)
          end

          store_object
        end
      end

      class StringKeyedHashAccessor < HashAccessor # :nodoc:
        def self.get(store_object, key)
          super store_object, Symbol === key ? key.name : key.to_s
        end

        def self.read(object, attribute, key)
          super object, attribute, Symbol === key ? key.name : key.to_s
        end

        def self.write(object, attribute, key, value)
          super object, attribute, Symbol === key ? key.name : key.to_s, value
        end
      end

      class IndifferentHashAccessor < ActiveRecord::Store::HashAccessor # :nodoc:
        def self.get(store_object, key)
          if store_object
            IndifferentCoder.as_indifferent_hash(store_object)[key]
          end
        end

        def self.prepare(object, attribute)
          store_object = object.public_send(attribute)

          unless store_object.is_a?(ActiveSupport::HashWithIndifferentAccess)
            store_object = IndifferentCoder.as_indifferent_hash(store_object)
            object.public_send :"#{attribute}=", store_object
          end

          store_object
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
