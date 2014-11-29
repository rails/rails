module ActiveRecord
  module AttributeMethods
    module Write
      WriterMethodCache = Class.new(AttributeMethodCache) {
        private

        def method_body(method_name, const_name)
          <<-EOMETHOD
          def #{method_name}(value)
            name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{const_name}
            write_attribute(name, value)
          end
          EOMETHOD
        end
      }.new

      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods
        protected

        def define_method_attribute=(name)
          method = WriterMethodCache[name]
          generated_attribute_methods.module_eval {
            define_method "#{name}=", method
          }
        end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the
      # specified +value+. Empty strings for fixnum and float columns are
      # turned into +nil+.
      def write_attribute(attr_name, value)
        write_attribute_with_type_cast(attr_name, value, true)
      end

      def raw_write_attribute(attr_name, value)
        write_attribute_with_type_cast(attr_name, value, false)
      end

      private
      # Handle *= for method_missing.
      def attribute=(attribute_name, value)
        write_attribute(attribute_name, value)
      end

      def write_attribute_with_type_cast(attr_name, value, should_type_cast)
        attr_name = attr_name.to_s
        attr_name = self.class.primary_key if attr_name == 'id' && self.class.primary_key

        if should_type_cast
          @attributes.write_from_user(attr_name, value)
        else
          @attributes.write_from_database(attr_name, value)
        end

        value
      end
    end
  end
end
