# frozen_string_literal: true

module ActiveModel
  module SecurePassword
    class Argon2Password
      def initialize
        # Load argon2 gem only when has_secure_password with :argon2 is used.
        # This is to avoid Active Model (and by extension the entire framework)
        # being dependent on a binary library.
        require "argon2"
      rescue LoadError
        warn "You don't have argon2 installed in your application. Please add it to your Gemfile and run bundle install."
        raise
      end

      # Hashes the unencrypted password using Argon2.
      def hash_password(unencrypted_password)
        if ActiveModel::SecurePassword.min_cost
          ::Argon2::Password.new(profile: :unsafe_cheapest).create(unencrypted_password)
        else
          ::Argon2::Password.create(unencrypted_password)
        end
      end

      # Verifies if the password matches the digest.
      def verify_password(password, digest)
        ::Argon2::Password.verify_password(password, digest)
      end

      # Generates the salt from the password digest.
      def password_salt(digest)
        ::Argon2::HashFormat.new(digest).salt
      end

      # Validates the password and adds error to the record in the given attribute.
      # Argon2 has no maximum input size, no validation needed.
      def validate(_record, _attribute)
      end

      # Returns the algorithm name.
      def algorithm_name
        :argon2
      end
    end
  end
end
