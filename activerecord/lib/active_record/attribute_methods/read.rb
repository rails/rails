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

      ##
      # :method: read_attribute
      # :call-seq: read_attribute(attr_name, &block)
      #
      # See ActiveModel::AttributeMethods#read_attribute.

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
