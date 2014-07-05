module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      included do
        # Returns a hash of all the attributes that have been specified for
        # serialization as keys and their class restriction as values.
        class_attribute :serialized_attributes, instance_accessor: false
        self.serialized_attributes = {}
      end

      module ClassMethods
        ##
        # :method: serialized_attributes
        #
        # Returns a hash of all the attributes that have been specified for
        # serialization as keys and their class restriction as values.

        # If you have an attribute that needs to be saved to the database as an
        # object, and retrieved as the same object, then specify the name of that
        # attribute using this method and it will be handled automatically. The
        # serialization is done through YAML. If +class_name+ is specified, the
        # serialized object must be of that class on retrieval or
        # <tt>SerializationTypeMismatch</tt> will be raised.
        #
        # A notable side effect of serialized attributes is that the model will
        # be updated on every save, even if it is not dirty.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The field name that should be serialized.
        # * +class_name_or_coder+ - Optional, a coder object, which responds to `.load` / `.dump`
        #   or a class name that the object type should be equal to.
        #
        # ==== Example
        #
        #   # Serialize a preferences attribute.
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        #
        #   # Serialize preferences using JSON as coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, JSON
        #   end
        #
        #   # Serialize preferences as Hash using YAML coder.
        #   class User < ActiveRecord::Base
        #     serialize :preferences, Hash
        #   end
        def serialize(attr_name, class_name_or_coder = Object)
          include Behavior

          # When ::JSON is used, force it to go through the Active Support JSON encoder
          # to ensure special objects (e.g. Active Record models) are dumped correctly
          # using the #as_json hook.
          coder = if class_name_or_coder == ::JSON
                    Coders::JSON
                  elsif [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
                    class_name_or_coder
                  else
                    Coders::YAMLColumn.new(class_name_or_coder)
                  end

          # merge new serialized attribute and create new hash to ensure that each class in inheritance hierarchy
          # has its own hash of own serialized attributes
          self.serialized_attributes = serialized_attributes.merge(attr_name.to_s => coder)
        end
      end

      class Type # :nodoc:
        def initialize(column)
          @column = column
        end

        def type_cast(value)
          if value.state == :serialized
            value.unserialized_value @column.type_cast value.value
          else
            value.unserialized_value
          end
        end

        def type
          @column.type
        end

        def accessor
          ActiveRecord::Store::IndifferentHashAccessor
        end
      end

      class Attribute < Struct.new(:coder, :value, :state) # :nodoc:
        def unserialized_value(v = value)
          state == :serialized ? unserialize(v) : value
        end

        def serialized_value
          state == :unserialized ? serialize : value
        end

        def unserialize(v)
          self.state = :unserialized
          self.value = coder.load(v)
        end

        def serialize
          self.state = :serialized
          self.value = coder.dump(value)
        end
      end

      # This is only added to the model when serialize is called, which
      # ensures we do not make things slower when serialization is not used.
      module Behavior # :nodoc:
        extend ActiveSupport::Concern

        module ClassMethods # :nodoc:
          def initialize_attributes(attributes, options = {})
            serialized = (options.delete(:serialized) { true }) ? :serialized : :unserialized
            super(attributes, options)

            serialized_attributes.each do |key, coder|
              if attributes.key?(key)
                attributes[key] = Attribute.new(coder, attributes[key], serialized)
              end
            end

            attributes
          end
        end

        def should_record_timestamps?
          super || (self.record_timestamps && (attributes.keys & self.class.serialized_attributes.keys).present?)
        end

        def keys_for_partial_write
          super | (attributes.keys & self.class.serialized_attributes.keys)
        end

        def type_cast_attribute_for_write(column, value)
          if column && coder = self.class.serialized_attributes[column.name]
            Attribute.new(coder, value, :unserialized)
          else
            super
          end
        end

        def raw_type_cast_attribute_for_write(column, value)
          if column && coder = self.class.serialized_attributes[column.name]
            Attribute.new(coder, value, :serialized)
          else
            super
          end
        end

        def _field_changed?(attr, old, value)
          if self.class.serialized_attributes.include?(attr)
            old != value
          else
            super
          end
        end

        def read_attribute_before_type_cast(attr_name)
          if self.class.serialized_attributes.include?(attr_name)
            super.unserialized_value
          else
            super
          end
        end

        def attributes_before_type_cast
          super.dup.tap do |attributes|
            self.class.serialized_attributes.each_key do |key|
              if attributes.key?(key)
                attributes[key] = attributes[key].unserialized_value
              end
            end
          end
        end

        def typecasted_attribute_value(name)
          if self.class.serialized_attributes.include?(name)
            @attributes[name].serialized_value
          else
            super
          end
        end

        def attributes_for_coder
          attribute_names.each_with_object({}) do |name, attrs|
            attrs[name] = if self.class.serialized_attributes.include?(name)
                            @attributes[name].serialized_value
                          else
                            read_attribute(name)
                          end
          end
        end
      end
    end
  end
end
