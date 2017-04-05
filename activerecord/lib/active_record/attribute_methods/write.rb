module ActiveRecord
  module AttributeMethods
    module Write
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods
        private

          def define_method_attribute=(name)
            safe_name = name.unpack("h*".freeze).first
            ActiveRecord::AttributeMethods::AttrNames.set_name_cache safe_name, name

            generated_attribute_methods.module_eval <<-STR, __FILE__, __LINE__ + 1
              def __temp__#{safe_name}=(value)
                name = ::ActiveRecord::AttributeMethods::AttrNames::ATTR_#{safe_name}
                write_attribute(name, value)
              end
              alias_method #{(name + '=').inspect}, :__temp__#{safe_name}=
              undef_method :__temp__#{safe_name}=
            STR
          end
      end

      # Updates the attribute identified by <tt>attr_name</tt> with the
      # specified +value+. Empty strings for Integer and Float columns are
      # turned into +nil+.
      def write_attribute(attr_name, value)
        name = if self.class.attribute_alias?(attr_name)
          self.class.attribute_alias(attr_name).to_s
        else
          attr_name.to_s
        end

        write_attribute_with_type_cast(name, value, true)
      end

      def raw_write_attribute(attr_name, value) # :nodoc:
        write_attribute_with_type_cast(attr_name, value, false)
      end

      private
        # Handle *= for method_missing.
        def attribute=(attribute_name, value)
          write_attribute(attribute_name, value)
        end

        def write_attribute_with_type_cast(attr_name, value, should_type_cast)
          attr_name = attr_name.to_s
          attr_name = self.class.primary_key if attr_name == "id" && self.class.primary_key

          if should_type_cast
            @attributes.write_from_user(attr_name, value)
          else
            @attributes.write_cast_value(attr_name, value)
          end

          value
        end
    end
  end
end
