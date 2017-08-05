# frozen_string_literal: true

class PersonWithValidator
  include ActiveModel::Validations

  class PresenceValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors[attribute] << "Local validator#{options[:custom]}" if value.blank?
    end
  end

  class LikeValidator < ActiveModel::EachValidator
    def initialize(options)
      @with = options[:with]
      super
    end

    def validate_each(record, attribute, value)
      unless value[@with]
        record.errors.add attribute, "does not appear to be like #{@with}"
      end
    end
  end

  attr_accessor :title, :karma
end
