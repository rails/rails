# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods \Write
    module Write
      extend ActiveSupport::Concern

      included do
        attribute_method_suffix "=", parameters: "value"
      end

      module ClassMethods # :nodoc:
        private
          def define_method_attribute=(canonical_name, owner:, as: canonical_name)
            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              owner, canonical_name, writer: true,
            ) do |temp_method_name, attr_name_expr|
              owner.define_cached_method(temp_method_name, as: "#{as}=", namespace: :active_record) do |batch|
                batch <<
                  "def #{temp_method_name}(value)" <<
                  "  _write_attribute(#{attr_name_expr}, value)" <<
                  "end"
              end
            end
          end
      end

      # Updates the attribute identified by +attr_name+ using the specified
      # +value+. The attribute value will be type cast upon being read.
      def write_attribute(attr_name, value)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        name = @primary_key if name == "id" && @primary_key
        @attributes.write_from_user(name, value)
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the write_attribute API
      def _write_attribute(attr_name, value) # :nodoc:
        @attributes.write_from_user(attr_name, value)
      end

      alias :attribute= :_write_attribute
      private :attribute=
    end
  end
end
