# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module AttributeMethods
    # Active Record Attribute Methods \Read
    # =====================================
    module Read
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        private
          def define_method_attribute(canonical_name, owner:, as: canonical_name)
            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              canonical_name
            ) do |temp_method_name, attr_name_expr|
              owner.define_cached_method(temp_method_name, as: as, namespace: :active_record) do |batch|
                batch <<
                  "def #{temp_method_name}" <<
                  "  _read_attribute!(#{attr_name_expr})" <<
                  "end"
              end
            end
          end
      end

      # Returns the value of the attribute identified by `attr_name` after it
      # has been type cast. For example, a date attribute will cast "2004-12-12"
      # to `Date.new(2004, 12, 12)`. (For information about specific type
      # casting behavior, see the types under ActiveModel::Type.)
      def read_attribute(attr_name, &block)
        name = resolve_alias(attr_name.to_s)

        @attributes.fetch_value(name, &block)
      end

      # Like #read_attribute, but +attr_name+ must be a String, and a missing
      # attribute raises ActiveModel::MissingAttributeError.
      # We assume that attribute name is a string.  This is an internal method,
      # don't call it!
      def read_attr(attr_name) # :nodoc:
        @attributes.fetch_value!(resolve_alias(attr_name))
      end

      # Internal read without alias resolution. An uninitialized attribute returns nil.
      def _read_attribute(attr_name) # :nodoc:
        @attributes.fetch_value(attr_name)
      end

      # Internal read without alias resolution that raises for uninitialized attributes.
      def _read_attribute!(attr_name) # :nodoc:
        @attributes.fetch_value!(attr_name)
      rescue ActiveModel::MissingAttributeError
        raise if @attributes.key?(attr_name)
        missing_attribute(attr_name, caller)
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
