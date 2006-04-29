module ActiveRecord
  # A plugin framework for wrapping attribute values before they go in and unwrapping them after they go out of the database.
  # This was intended primarily for YAML wrapping of arrays and hashes, but this behavior is now native in the Base class.
  # So for now this framework is laying dormant until a need pops up.
  module Wrappings #:nodoc:
    module ClassMethods #:nodoc:
      def wrap_with(wrapper, *attributes)
        [ attributes ].flat.each { |attribute| wrapper.wrap(attribute) }
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    class AbstractWrapper #:nodoc:
      def self.wrap(attribute, record_binding) #:nodoc:
        %w( before_save after_save after_initialize ).each do |callback|
          eval "#{callback} #{name}.new('#{attribute}')", record_binding
        end
      end

      def initialize(attribute) #:nodoc:
        @attribute = attribute
      end

      def save_wrapped_attribute(record) #:nodoc:
        if record.attribute_present?(@attribute)
          record.send(
            "write_attribute", 
            @attribute, 
            wrap(record.send("read_attribute", @attribute))
          )
        end
      end

      def load_wrapped_attribute(record) #:nodoc:
        if record.attribute_present?(@attribute)
          record.send(
            "write_attribute", 
            @attribute, 
            unwrap(record.send("read_attribute", @attribute))
          )
        end
      end
  
      alias_method :before_save, :save_wrapped_attribute #:nodoc:
      alias_method :after_save, :load_wrapped_attribute #:nodoc:
      alias_method :after_initialize, :after_save #:nodoc:

      # Overwrite to implement the logic that'll take the regular attribute and wrap it.
      def wrap(attribute) end
  
      # Overwrite to implement the logic that'll take the wrapped attribute and unwrap it.
      def unwrap(attribute) end
    end
  end
end
