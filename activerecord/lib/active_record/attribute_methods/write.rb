# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module Write
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "="
      end

      module ClassMethods # :nodoc:
        private

          def define_method_attribute=(name)
            sync_with_transaction_state = "sync_with_transaction_state" if name == primary_key

            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              generated_attribute_methods, name, writer: true,
            ) do |temp_method_name, attr_name_expr|
              generated_attribute_methods.module_eval <<-RUBY, __FILE__, __LINE__ + 1
                def #{temp_method_name}(value)
                  name = #{attr_name_expr}
                  #{sync_with_transaction_state}
                  _write_attribute(name, value)
                end
              RUBY
            end
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

        primary_key = self.class.primary_key
        name = primary_key if name == "id" && primary_key
        sync_with_transaction_state if name == primary_key
        _write_attribute(name, value)
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the write_attribute API
      def _write_attribute(attr_name, value) # :nodoc:
        @attributes.write_from_user(attr_name.to_s, value)
        value
      end

      private
        def write_attribute_without_type_cast(attr_name, value)
          name = attr_name.to_s
          @attributes.write_cast_value(name, value)
          value
        end

        # Handle *= for method_missing.
        def attribute=(attribute_name, value)
          _write_attribute(attribute_name, value)
        end
    end
  end
end
