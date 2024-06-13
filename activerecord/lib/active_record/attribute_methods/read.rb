# frozen_string_literal: true

module ActiveRecord
  module AttributeMethods
    # = Active Record Attribute Methods \Read
    module Read
      extend ActiveSupport::Concern

      module ClassMethods # :nodoc:
        private
          def define_method_attribute(canonical_name, owner:, as: canonical_name)
            ActiveModel::AttributeMethods::AttrNames.define_attribute_accessor_method(
              owner, canonical_name
            ) do |temp_method_name, attr_name_expr|
              owner.define_cached_method(temp_method_name, as: as, namespace: :active_record) do |batch|
                batch <<
                  "def #{temp_method_name}" <<
                  "  _read_attribute(#{attr_name_expr}) { |n| missing_attribute(n, caller) }" <<
                  "end"
              end
            end
          end
      end

      # Returns the value of the attribute identified by +attr_name+ after it
      # has been type cast. For example, a date attribute will cast "2004-12-12"
      # to <tt>Date.new(2004, 12, 12)</tt>. (For information about specific type
      # casting behavior, see the types under ActiveModel::Type.)
      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        return @attributes.fetch_value(name, &block) unless name == "id" && @primary_key

        if self.class.composite_primary_key?
          @attributes.fetch_value("id", &block)
        else
          if @primary_key != "id"
            ActiveRecord.deprecator.warn(<<-MSG.squish)
              Using read_attribute(:id) to read the primary key value is deprecated.
              Use #id instead.
            MSG
          end
          @attributes.fetch_value(@primary_key, &block)
        end
      end

      # This method exists to avoid the expensive primary_key check internally, without
      # breaking compatibility with the read_attribute API
      def _read_attribute(attr_name, &block) # :nodoc:
        @attributes.fetch_value(attr_name, &block)
      end

      alias :attribute :_read_attribute
      private :attribute
    end
  end
end
