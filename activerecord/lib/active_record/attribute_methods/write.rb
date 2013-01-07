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
            if attr_name =~ ActiveModel::AttributeMethods::NAME_COMPILABLE_REGEXP
              generated_attribute_methods.module_eval("def #{attr_name}=(new_value); write_attribute('#{attr_name}', new_value); end", __FILE__, __LINE__)
            else
              generated_attribute_methods.send(:define_method, "#{attr_name}=") do |new_value|
                write_attribute(attr_name, new_value)
              end
            end
          end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the specified +value+. Empty strings
      # for fixnum and float columns are turned into +nil+.
      def write_attribute(attr_name, value)
        attr_name = attr_name.to_s
        attr_name = self.class.primary_key if attr_name == 'id' && self.class.primary_key
        @attributes_cache.delete(attr_name)
        column = column_for_attribute(attr_name)

        unless column || @attributes.has_key?(attr_name)
          ActiveSupport::Deprecation.warn(
            "You're trying to create an attribute `#{attr_name}'. Writing arbitrary " \
            "attributes on a model is deprecated. Please just use `attr_writer` etc."
          )
        end

        @attributes[attr_name] = type_cast_attribute_for_write(column, value)
      end
      alias_method :raw_write_attribute, :write_attribute

      private
        # Handle *= for method_missing.
        def attribute=(attribute_name, value)
          write_attribute(attribute_name, value)
        end

        def type_cast_attribute_for_write(column, value)
          if column && column.number?
            convert_number_column_value(value)
          else
            value
          end
        end

        def convert_number_column_value(value)
          case value
          when FalseClass
            0
          when TrueClass
            1
          when String
            value.presence
          else
            value
          end
        end
    end
  end
end
