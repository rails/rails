# frozen_string_literal: true

module ActiveModel
  module SecurePassword
    class BCrypt < Base
      # BCrypt hash function can handle maximum 72 bytes, and if we pass
      # password of length more than 72 bytes it ignores extra characters.
      # Hence need to put a restriction on password length.
      MAX_PASSWORD_LENGTH_ALLOWED = 72

      # Load bcrypt gem only when has_secure_password is used.
      # This is to avoid ActiveModel (and by extension the entire framework)
      # being dependent on a binary library.
      def initialize
        require "bcrypt"
      rescue LoadError
        warn "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install."
        raise
      end

      def self.algorithm_name
        :bcrypt
      end

      def validate(record, attribute)
        password_value = record.public_send(attribute)
        if password_value.present?
          record.errors.add(attribute, :password_too_long) if password_value.bytesize > MAX_PASSWORD_LENGTH_ALLOWED
        end
      end

      def hash_password(unencrypted_password, options = {})
        cost = options[:min_cost] ? ::BCrypt::Engine::MIN_COST : ::BCrypt::Engine.cost
        ::BCrypt::Password.create(unencrypted_password, cost: cost)
      end

      def verify_password(password, digest)
        ::BCrypt::Password.new(digest).is_password?(password)
      end

      def password_salt(digest)
        ::BCrypt::Password.new(digest).salt
      end
    end
  end
end
