# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A KeyProvider that derives keys from passwords.
    class DeterministicKeyProvider < DerivedSecretKeyProvider
      def initialize(password)
        passwords = Array(password)
        raise ActiveRecord::Encryption::Errors::Configuration, "Deterministic encryption keys can't be rotated" if passwords.length > 1
        super(passwords)
      end
    end
  end
end
