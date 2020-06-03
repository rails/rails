# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    module Read
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        private
          def define_method_attribute(name, owner:)
            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              owner, name
            ) do |temp_method_name, attr_name_expr|
              owner <<
                "def #{temp_method_name}" <<
                "  _read_attribute(#{attr_name_expr}) { |n| missing_attribute(n, caller) }" <<
                "end"
            end
          end
      end

      # Returns the value of the attribute identified by <tt>attr_name</tt> after
      # it has been typecast (for example, "2004-12-12" in a date column is cast
      # to a date object, like Date.new(2004, 12, 12)).
      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        name = @primary_key if name == "id" && @primary_key
        _read_attribute(name, &block)
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the read_attribute API
      def _read_attribute(attr_name, &block) # :nodoc
        @attributes.fetch_value(attr_name, &block)
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
