module ActiveRecord
  module SecureKey
    extend ActiveSupport::Concern

    MAX_TRIES = 1000

    module ClassMethods
      def has_secure_key(attribute, options = {})
        # Load securerandom only when has_secure_key is used.
        require 'securerandom'
        key_length = options.fetch(:key_length, 24)

        before_create "set_generated_#{ attribute }_key"

        define_method("rekey_#{ attribute }!") do
          send("set_generated_#{ attribute }_key")
          save!
        end

        define_method("set_generated_#{ attribute }_key") do
          public_send "#{ attribute }=", self.class.generate_unique_secure_key(key_length) { |key| self.class.exists?(attribute => key) }
        end

        private "set_generated_#{ attribute }_key"
      end

      def generate_unique_secure_key(key_length) #:nodoc:
        bytes = (key_length / 2.0).ceil
        MAX_TRIES.times do
          token = SecureRandom.hex(bytes).first(key_length)
          return token unless yield(token)
        end
        raise RetriesLimitReached, "No unique key found after #{ MAX_TRIES } tries"
      end
    end
  end
end
