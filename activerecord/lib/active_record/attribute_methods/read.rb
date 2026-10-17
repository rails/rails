# frozen_string_literal: true

# :markup: markdown
module ActiveRecord
  module AttributeMethods
    # Active Record Attribute Methods \Read
    # =====================================
    module Read
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        def resolve_alias(attr_name) # :nodoc:
          attribute_aliases[attr_name] || attr_name
        end

        private
          def define_method_attribute(canonical_name, owner:, as: canonical_name)
            # Don't load the schema here, methods can be defined on classes
            # without a table (e.g. alias_attribute on an abstract class).
            ord = attributes_builder.indexes[canonical_name]&.ord if schema_loaded?

            # Generated methods are cached by name and shared between models,
            # so readers that embed an ord are cached per ord.
            namespace = ord ? :"active_record_ord_#{ord}" : :active_record

            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              canonical_name
            ) do |temp_method_name, attr_name_expr|
              read = if ord
                "read_attribute_at(#{ord})"
              else
                "_read_attribute(#{attr_name_expr})"
              end

              owner.define_cached_method(temp_method_name, as: as, namespace: namespace) do |batch|
                batch <<
                  "def #{temp_method_name}" <<
                  "  #{read} { |n| missing_attribute(n, caller) }" <<
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

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the read_attribute API
      def _read_attribute(attr_name, &block) # :nodoc:
        @attributes.fetch_value(attr_name, &block)
      end

      # Like #_read_attribute, but a missing attribute raises
      # ActiveModel::MissingAttributeError.
      def _read_attr(attr_name) # :nodoc:
        @attributes.fetch_value!(attr_name)
      end

      # Like #_read_attribute, but takes the attribute's +index+ (its
      # column's +ord+) instead of its name. Called by the generated reader
      # methods for attributes that have a column.
      def read_attribute_at(index, &block) # :nodoc:
        @attributes.fetch_value_at(index, &block)
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
