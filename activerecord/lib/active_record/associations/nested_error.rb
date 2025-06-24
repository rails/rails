# frozen_string_literal: true

# Validation error class to wrap association records' errors,
# with index_errors support.
module ActiveRecord
  module Associations
    class NestedError < ::ActiveModel::NestedError
      def initialize(association, inner_error)
        @base = association.owner
        @association = association
        @inner_error = inner_error
        super(@base, inner_error, { attribute: compute_attribute(inner_error) })
      end

      private
        attr_reader :association

        def compute_attribute(inner_error)
          association_name = association.reflection.name

          if association.collection? && index_errors_setting && index
            "#{association_name}[#{index}].#{inner_error.attribute}".to_sym
          else
            "#{association_name}.#{inner_error.attribute}".to_sym
          end
        end

        def index_errors_setting
          @index_errors_setting ||=
            association.options.fetch(:index_errors, ActiveRecord.index_nested_attribute_errors)
        end

        def index
          @index ||= ordered_records&.find_index(inner_error.base)
        end

        def ordered_records
          case index_errors_setting
          when true # default is association order
            association.target
          when :nested_attributes_order
            association.nested_attributes_target
          end
        end
    end
  end
end
