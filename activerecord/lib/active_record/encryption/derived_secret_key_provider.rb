# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A KeyProvider that derives keys from passwords.
    class DerivedSecretKeyProvider < KeyProvider
      def initialize(passwords)
        super(Array(passwords).collect { |password| Key.derive_from(password) })
      end
    end
  end
end
