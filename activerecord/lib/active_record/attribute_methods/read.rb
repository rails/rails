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
          #: (String, owner: ActiveSupport::CodeGenerator, ?as: String) -> void
          def define_method_attribute(canonical_name, owner:, as: canonical_name)
            slot = attributes_builder.indexes[canonical_name]
            unless slot
              raise ArgumentError, "#{self.name} has no attribute `#{canonical_name}` to define a reader for"
            end

            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              "_read_attribute_#{slot}"
            ) do |temp_method_name|
              owner.define_cached_method(temp_method_name, as: as, namespace: :active_record_slot) do |batch|
                batch <<
                  "def #{temp_method_name}" <<
                  "  _read_attribute_at!(#{slot})" <<
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
        name = resolve_alias(attr_name.is_a?(Symbol) ? attr_name.name : attr_name.to_s)

        @attributes.fetch_value(name, &block)
      end

      # Like #read_attribute, but +attr_name+ must be a String and no block is
      # forwarded. An uninitialized attribute returns nil.
      def read_attr(attr_name) # :nodoc:
        attr_name = resolve_alias(attr_name)
        @attributes.fetch_value!(attr_name)
      rescue ActiveModel::MissingAttributeError
        raise if @attributes.key?(attr_name)
      end

      # Internal read without alias resolution. An uninitialized attribute returns nil.
      def _read_attribute(attr_name) # :nodoc:
        @attributes.fetch_value!(attr_name)
      rescue ActiveModel::MissingAttributeError
        raise if @attributes.key?(attr_name)
      end

      # Internal read without alias resolution that raises for uninitialized attributes.
      def _read_attribute!(attr_name) # :nodoc:
        @attributes.fetch_value!(attr_name)
      rescue ActiveModel::MissingAttributeError
        raise if @attributes.key?(attr_name)
        missing_attribute(attr_name, RUBY_VERSION >= "3.4" ? caller_locations : caller)
      end

      # Like #_read_attribute, but takes the attribute's +index+ (its slot)
      # instead of its name, and raises for uninitialized attributes. Called
      # by the generated reader methods.
      #: (Integer) -> untyped
      def _read_attribute_at!(index) # :nodoc:
        @attributes.fetch_value_at!(index)
      rescue ActiveModel::MissingAttributeError
        attr_name = @attributes.name_at(index)
        raise if @attributes.key?(attr_name)
        missing_attribute(attr_name, RUBY_VERSION >= "3.4" ? caller_locations : caller)
      rescue ActiveModel::LazyAttributeSet::NotLaidOut
        # Loaded from a Rails 6.1 Marshal dump, so the attributes need the
        # model's layout before they can be read by slot.
        @attributes = self.class.attributes_builder.relayout_attributes(@attributes)
        retry
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
