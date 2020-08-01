# frozen_string_literal: true

module ActiveRecord
  module Returning
    extend ActiveSupport::Concern

    included do
      class_attribute :_returning, instance_accessor: false, default: []
    end

    module ClassMethods
      # Attributes listed as returning, will be requested as part of the DB response when
      # creating or updating a record.
      def returning(*attributes)
        self._returning = Set.new(attributes.map(&:to_s)) + (_returning || [])
      end

      # Returns an array of all the attributes marked to be returned on create/update.
      def returning_attributes
        _returning
      end
    end
  end
end
