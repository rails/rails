class PersonWithValidator
  include ActiveModel::Validations

  class PresenceValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      record.errors[attribute] << "Local validator#{options[:custom]}" if value.blank?
    end
  end

  attr_accessor :title, :karma
end
