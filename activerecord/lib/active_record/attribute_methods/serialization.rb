module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      included do
        # Returns a hash of all the attributes that have been specified for
        # serialization as keys and their class restriction as values.
        class_attribute :serialized_attributes, instance_accessor: false
        self.serialized_attributes = {}
      end

      module ClassMethods
        # If you have an attribute that needs to be saved to the database as an
        # object, and retrieved as the same object, then specify the name of that
        # attribute using this method and it will be handled automatically. The
        # serialization is done through YAML. If +class_name+ is specified, the
        # serialized object must be of that class on retrieval or
        # <tt>SerializationTypeMismatch</tt> will be raised.
        #
        # ==== Parameters
        #
        # * +attr_name+ - The field name that should be serialized.
        # * +class_name+ - Optional, class name that the object type should be equal to.
        #
        # ==== Example
        #
        #   # Serialize a preferences attribute.
        #   class User < ActiveRecord::Base
        #     serialize :preferences
        #   end
        def serialize(attr_name, class_name = Object)
          include Behavior

          coder = if [:load, :dump].all? { |x| class_name.respond_to?(x) }
                    class_name
                  else
                    Coders::YAMLColumn.new(class_name)
                  end

          # merge new serialized attribute and create new hash to ensure that each class in inheritance hierarchy
          # has its own hash of own serialized attributes
          self.serialized_attributes = serialized_attributes.merge(attr_name.to_s => coder)
        end
      end

      def serialized_attributes
        ActiveSupport::Deprecation.warn("Instance level serialized_attributes method is deprecated, please use class level method.")
        defined?(@serialized_attributes) ? @serialized_attributes : self.class.serialized_attributes
      end

      class Type # :nodoc:
        def initialize(column)
          @column = column
        end

        def type_cast(value)
          value.unserialized_value
        end

        def type
          @column.type
        end
      end

      class Attribute < Struct.new(:coder, :value, :state) # :nodoc:
        def unserialized_value
          state == :serialized ? unserialize : value
        end

        def serialized_value
          state == :unserialized ? serialize : value
        end

        def unserialize
          self.state = :unserialized
          self.value = coder.load(value)
        end

        def serialize
          self.state = :serialized
          self.value = coder.dump(value)
        end
      end

      # This is only added to the model when serialize is called, which
      # ensures we do not make things slower when serialization is not used.
      module Behavior #:nodoc:
        extend ActiveSupport::Concern

        module ClassMethods
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

        def type_cast_attribute_for_write(column, value)
          if column && coder = self.class.serialized_attributes[column.name]
            Attribute.new(coder, value, :unserialized)
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
      end
    end
  end
end
