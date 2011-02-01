module ActiveRecord
  module AttributeMethods
    module Write
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods
        protected
          def define_method_attribute=(attr_name)
            generated_attribute_methods.module_eval("def #{attr_name}=(new_value); write_attribute('#{attr_name}', new_value); end", __FILE__, __LINE__)
          end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings
      # for fixnum and float columns are turned into +nil+.
      def write_attribute(attr_name, value)
        attr_name = attr_name.to_s
        attr_name = self.class.primary_key if attr_name == 'id'
        @attributes_cache.delete(attr_name)
        if (column = column_for_attribute(attr_name)) && column.number?
          @attributes[attr_name] = convert_number_column_value(value)
        else
          @attributes[attr_name] = value
        end
      end

      private
        # Handle *= for method_missing.
        def attribute=(attribute_name, value)
          write_attribute(attribute_name, value)
        end
    end
  end
end
