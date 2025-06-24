# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A KeyProvider that derives keys from passwords.
    class DerivedSecretKeyProvider < KeyProvider
      def initialize(passwords, key_generator: ActiveRecord::Encryption.key_generator)
        super(Array(passwords).collect { |password| derive_key_from(password, using: key_generator) })
      end

      private
        def derive_key_from(password, using: key_generator)
          secret = using.derive_key_from(password)
          ActiveRecord::Encryption::Key.new(secret)
        end
    end
  end
end
