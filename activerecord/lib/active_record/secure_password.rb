# frozen_string_literal: true

module ActiveRecord
  module SecurePassword
    extend ActiveSupport::Concern

    include ActiveModel::SecurePassword

    module ClassMethods
      # Given a set of attributes, finds a record using the non-password
      # attributes, and then authenticates that record using the password
      # attributes. Returns the record if authentication succeeds; otherwise,
      # returns +nil+.
      #
      # Regardless of whether a record is found, +authenticate_by+ will
      # cryptographically digest the given password attributes. This behavior
      # helps mitigate timing-based enumeration attacks, wherein an attacker can
      # determine if a passworded record exists even without knowing the
      # password.
      #
      # Raises an ArgumentError if the set of attributes doesn't contain at
      # least one password and one non-password attribute.
      #
      # ==== Examples
      #
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   User.create(name: "John Doe", email: "jdoe@example.com", password: "abc123")
      #
      #   User.authenticate_by(email: "jdoe@example.com", password: "abc123").name # => "John Doe" (in 373.4ms)
      #   User.authenticate_by(email: "jdoe@example.com", password: "wrong")       # => nil (in 373.9ms)
      #   User.authenticate_by(email: "wrong@example.com", password: "abc123")     # => nil (in 373.6ms)
      #
      #   User.authenticate_by(email: "jdoe@example.com", password: nil) # => nil (no queries executed)
      #   User.authenticate_by(email: "jdoe@example.com", password: "")  # => nil (no queries executed)
      #
      #   User.authenticate_by(email: "jdoe@example.com") # => ArgumentError
      #   User.authenticate_by(password: "abc123")        # => ArgumentError
      def authenticate_by(attributes)
        passwords, identifiers = attributes.to_h.partition do |name, value|
          !has_attribute?(name) && has_attribute?("#{name}_digest")
        end.map(&:to_h)

        raise ArgumentError, "One or more password arguments are required" if passwords.empty?
        raise ArgumentError, "One or more finder arguments are required" if identifiers.empty?

        return if passwords.any? { |name, value| value.nil? || value.empty? }

        if record = find_by(identifiers)
          record if passwords.count { |name, value| record.public_send(:"authenticate_#{name}", value) } == passwords.size
        else
          new(passwords)
          nil
        end
      end
    end
  end
end
