# frozen_string_literal: true

module ActiveModel
  module ComplexPassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to allow for password complexity validation across
      # presence of a number, special character, lowercase letter, and uppercase letter.
      #
      # ==== Examples
      #
      # ===== Using default password complexity requirements
      #   class User
      #     include ActiveModel::ComplexPassword
      #     attr_accessor :password
      #     has_complex_password
      #   end
      #
      #   user = User.new
      #   user
      #   user.valid? # => false
      #   user.errors[:password] # => ["can't be blank", "must contain at least one number", "must contain at least one special character", "must contain at least one lowercase letter", "must contain at least one uppercase letter"]
      #
      #   user = User.new(password = "Abc123!")
      #   user.valid? # => true
      #
      # ===== Customizing password complexity requirements
      #   class User
      #     include ActiveModel::ComplexPassword
      #     attr_accessor :secret
      #     has_complex_password(:secret, must_contain_number: false)
      #   end
      #
      #   user = User.new
      #   user.valid? # => false
      #   user.errors[:secret] # => ["can't be blank", "must contain at least one special character", "must contain at least one lowercase letter", "must contain at least one uppercase letter"]
      #
      #   user = User.new(password = "ABCabc!")
      #   user.valid? # => true
      def has_complex_password(
        attribute = :password,
        must_contain_number: true,
        must_contain_special_character: true,
        must_contain_lowercase: true,
        must_contain_uppercase: true,
        special_characters: "!?@#$%^&*()_+-=[]{}|:;<>,./")

        validate do |record|
          record.errors.add(attribute, :blank) unless record.public_send(attribute).present?
        end

        validate do |record|
          if record.public_send(attribute).present?
            password = record.public_send(attribute)

            record.errors.add(attribute, :must_contain_number) if must_contain_number && !password.match(/\d/)
            record.errors.add(attribute, :must_contain_special_character) if must_contain_special_character && !password.match(/[#{Regexp.escape(special_characters)}]/)
            record.errors.add(attribute, :must_contain_lowercase) if must_contain_lowercase && !password.match(/\p{Lower}/)
            record.errors.add(attribute, :must_contain_uppercase) if must_contain_uppercase && !password.match(/\p{Upper}/)
          end
        end
      end
    end
  end
end
