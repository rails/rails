module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

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

          coder = if [:load, :dump].all? { |x| class_name_or_coder.respond_to?(x) }
                    class_name_or_coder
                  else
                    Coders::YAMLColumn.new(class_name_or_coder)
                  end

          type = columns_hash[attr_name.to_s].cast_type
          if type.serialized?
            type = type.subtype
          end
          property attr_name, Type::Serialized.new(type, coder)
        end

        def serialized_attributes
          ActiveSupport::Deprecation.warn(<<-MESSAGE.strip_heredoc)
            `serialized_attributes` has been removed. If you need a list of all serialized attributes,
            you can do so by doing `klass.columns.select(&:serialized?)`. The coder should be considered
            an internal implementation detail, and should not be directly accessed. You can load/dump from
            the coder by calling `type_cast` and `type_cast_for_write` on the column object.
          MESSAGE
        end
      end

      # This is only added to the model when serialize is called, which
      # ensures we do not make things slower when serialization is not used.
      module Behavior # :nodoc:
        extend ActiveSupport::Concern

        def should_record_timestamps?
          super || (self.record_timestamps && (attributes.keys & self.class.serialized_attributes.keys).present?)
        end

        def keys_for_partial_write
          super | (attributes.keys & self.class.serialized_attributes.keys)
        end

        def _field_changed?(attr, old, value)
          if self.class.serialized_attributes.include?(attr)
            old != value
          else
            super
          end
        end
      end
    end
  end
end
