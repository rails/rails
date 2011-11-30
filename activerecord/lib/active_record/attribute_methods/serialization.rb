module ActiveRecord
  module AttributeMethods
    module Serialization
      extend ActiveSupport::Concern

      module ClassMethods
        def define_method_attribute(attr_name)
          if serialized_attributes.include?(attr_name)
            generated_attribute_methods.module_eval(<<-CODE, __FILE__, __LINE__)
              def _#{attr_name}
                @attributes_cache['#{attr_name}'] ||= @attributes['#{attr_name}']
              end
              alias #{attr_name} _#{attr_name}
            CODE
          else
            super
          end
        end

        def cacheable_column?(column)
          serialized_attributes.include?(column.name) || super
        end
      end

      def type_cast_attribute(column, value)
        coder = self.class.serialized_attributes[column.name]

        if column.text? && coder
          unserialized_object = coder.load(@attributes[column.name])

          if @attributes.frozen?
            unserialized_object
          else
            @attributes[column.name] = unserialized_object
          end
        else
          super
        end
      end
    end
  end
end
