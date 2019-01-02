# frozen_string_literal: true

module ActiveStorage
  module Validations
    class AttachedValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        unless record.send(attribute).attached?
          record.errors.add(attribute, :blank)
        end
      end
    end
  end
end
