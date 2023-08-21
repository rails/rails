# frozen_string_literal: true

module ActiveModel
  module SecurePassword
    class Base
      def self.algorithm_name
        raise NotImplementedError
      end

      def algorithm_name
        self.class.algorithm_name
      end

      def validate(record)
        nil
      end

      def hash_password(unencrypted_password, options = {})
        raise NotImplementedError
      end

      def verify_password(password, digest)
        raise NotImplementedError
      end

      def password_salt(digest)
        raise NotImplementedError
      end
    end
  end
end

require "active_model/secure_password/bcrypt"
