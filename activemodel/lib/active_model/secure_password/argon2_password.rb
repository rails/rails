# frozen_string_literal: true

module ActiveModel
  module SecurePassword
    class Argon2Password
      # Load argon2 gem only when has_secure_password with :argon2 is used.
      # This is to avoid ActiveModel (and by extension the entire framework)
      # being dependent on a binary library.
      def initialize
        require "argon2"
      rescue LoadError
        warn "You don't have argon2 installed in your application. Please add it to your Gemfile and run bundle install."
        raise
      end

      def hash_password(unencrypted_password)
        if ActiveModel::SecurePassword.min_cost
          ::Argon2::Password.new(profile: :unsafe_cheapest).create(unencrypted_password)
        else
          ::Argon2::Password.create(unencrypted_password)
        end
      end

      def verify_password(password, digest)
        ::Argon2::Password.verify_password(password, digest)
      end

      def password_salt(digest)
        ::Argon2::HashFormat.new(digest).salt
      end

      def validate(_record, _attribute)
        # Argon2 has no maximum input size, no validation needed
      end

      def algorithm_name
        :argon2
      end
    end
  end
end
