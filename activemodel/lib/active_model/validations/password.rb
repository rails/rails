module ActiveModel
  module Validations
    class PasswordValidator < EachValidator
      WEAK_PASSWORDS = %w( password qwerty 123456 )
      REGEXES = {
        :weak   => /(?=.{6,}).*/, # 6 characters
        :medium => /^(?=.{7,})(((?=.*[A-Z])(?=.*[a-z]))|((?=.*[A-Z])(?=.*[0-9]))|((?=.*[a-z])(?=.*[0-9]))).*$/, #len=7 chars and numbers
        :strong => /^.*(?=.{8,})(?=.*[a-z])(?=.*[A-Z])(?=.*[\d\W]).*$/#len=8 chars and numbers and special chars
      }

      def validate_each(record, attribute, value)
        required_strength = options.fetch(:strength, :weak)

        if value.present?
          if value.size < 7
            record.errors.add(:password, "must be longer than 6 characters")
          elsif WEAK_PASSWORDS.include?(value)
            record.errors.add(:password, "is a too weak and common") 
          elsif (REGEXES[required_strength] !~ value)
            record.errors.add(attribute)
          end
        end
      end
    end
    module HelperMethods
      # Validates whether the value of the specified attribute is a password
      #
      #   class Person < ActiveRecord::Base
      #     validates_password :password, :strength => :strong
      #   end
      #
      # Configuration options:
      # * <tt>:strength</tt> - Can be either :weak (6 characters), :medium (7 characters w/ 1 digit), :strong (8 characters w/ 1 digit and 1 special character)
      def validates_password(*attr_names)
        validates_with PasswordValidator, _merge_attributes(attr_names)
      end
    end
  end
end
