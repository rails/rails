# frozen_string_literal: true

module ActiveRecord
  # = Active Record \Aggregations
  #
  # See ActiveModel::Aggregations::ClassMethods for documentation on #composed_of.
  # Active Record adds database-specific behavior.
  module Aggregations
    extend ActiveSupport::Concern
    include ActiveModel::Aggregations

    def reload(*) # :nodoc:
      clear_aggregation_cache
      super
    end

    private
      def clear_aggregation_cache
        @aggregation_cache.clear if persisted?
      end

      def init_internals
        super
        @aggregation_cache = {}
      end

      def _aggregation_read_attribute(key)
        read_attribute(key)
      end

      def _aggregation_write_attribute(key, value)
        write_attribute(key, value)
      end

      # == Finding records by a value object
      #
      # Once a #composed_of relationship is specified for a model, records can be loaded from the database
      # by specifying an instance of the value object in the conditions hash. The following example
      # finds all customers with +address_street+ equal to "May Street" and +address_city+ equal to "Chicago":
      #
      #   Customer.where(address: Address.new("May Street", "Chicago"))
      module ClassMethods
        include ActiveModel::Aggregations::ClassMethods

        # See ActiveModel::Aggregations::ClassMethods#composed_of for the options accepted here.
        def composed_of(part_id, options = {})
          super

          unless self < Aggregations
            include Aggregations
          end

          reflection = ActiveRecord::Reflection.create(:composed_of, part_id, nil, options, self)
          Reflection.add_aggregate_reflection self, part_id, reflection
        end
      end
  end
end
