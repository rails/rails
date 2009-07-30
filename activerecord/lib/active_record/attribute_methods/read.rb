module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix ""
      end

      module ClassMethods
        # +cache_attributes+ allows you to declare which converted attribute values should
        # be cached. Usually caching only pays off for attributes with expensive conversion
        # methods, like time related columns (e.g. +created_at+, +updated_at+).
        def cache_attributes(*attribute_names)
          attribute_names.each {|attr| cached_attributes << attr.to_s}
        end

        # Returns the attributes which are cached. By default time related columns
        # with datatype <tt>:datetime, :timestamp, :time, :date</tt> are cached.
        def cached_attributes
          @cached_attributes ||=
            columns.select{|c| attribute_types_cached_by_default.include?(c.type)}.map{|col| col.name}.to_set
        end

        # Returns +true+ if the provided attribute is being cached.
        def cache_attribute?(attr_name)
          cached_attributes.include?(attr_name)
        end

        protected
          def define_attribute_method(attr_name)
            if self.serialized_attributes[attr_name]
              define_read_method_for_serialized_attribute(attr_name)
            else
              define_read_method(attr_name.to_sym, attr_name, columns_hash[attr_name])
            end
          end

        private
          # Define read method for serialized attribute.
          def define_read_method_for_serialized_attribute(attr_name)
            evaluate_attribute_method attr_name, "def #{attr_name}; unserialize_attribute('#{attr_name}'); end", attr_name
          end

          # Define an attribute reader method.  Cope with nil column.
          def define_read_method(symbol, attr_name, column)
            cast_code = column.type_cast_code('v') if column
            access_code = cast_code ? "(v=@attributes['#{attr_name}']) && #{cast_code}" : "@attributes['#{attr_name}']"

            unless attr_name.to_s == self.primary_key.to_s
              access_code = access_code.insert(0, "missing_attribute('#{attr_name}', caller) unless @attributes.has_key?('#{attr_name}'); ")
            end

            if cache_attribute?(attr_name)
              access_code = "@attributes_cache['#{attr_name}'] ||= (#{access_code})"
            end
            evaluate_attribute_method attr_name, "def #{symbol}; #{access_code}; end", attr_name
          end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after it has been typecast (for example,
      # "2004-12-12" in a data column is cast to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name)
        attr_name = attr_name.to_s
        if !(value = @attributes[attr_name]).nil?
          if column = column_for_attribute(attr_name)
            if unserializable_attribute?(attr_name, column)
              unserialize_attribute(attr_name)
            else
              column.type_cast(value)
            end
          else
            value
          end
        else
          nil
        end
      end

      # A model instance's primary key is always available as model.id
      # whether you name it the default 'id' or set it to something else.
      def id
        attr_name = self.class.primary_key
        column = column_for_attribute(attr_name)

        self.class.send(:define_read_method, :id, attr_name, column)
        # now that the method exists, call it
        self.send attr_name.to_sym
      end

      # Returns true if the attribute is of a text column and marked for serialization.
      def unserializable_attribute?(attr_name, column)
        column.text? && self.class.serialized_attributes[attr_name]
      end

      # Returns the unserialized object of the attribute.
      def unserialize_attribute(attr_name)
        unserialized_object = object_from_yaml(@attributes[attr_name])

        if unserialized_object.is_a?(self.class.serialized_attributes[attr_name]) || unserialized_object.nil?
          @attributes.frozen? ? unserialized_object : @attributes[attr_name] = unserialized_object
        else
          raise SerializationTypeMismatch,
            "#{attr_name} was supposed to be a #{self.class.serialized_attributes[attr_name]}, but was a #{unserialized_object.class.to_s}"
        end
      end

      private
        def attribute(attribute_name)
          read_attribute(attribute_name)
        end
    end
  end
end
