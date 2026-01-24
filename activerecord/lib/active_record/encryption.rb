# frozen_string_literal: true

require "active_support/core_ext/module"
require "active_support/core_ext/array"

module ActiveRecord
  module Encryption
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AutoFilteredParameters
      autoload :Cipher
      autoload :Config
      autoload :Configurable
      autoload :Context
      autoload :Contexts
      autoload :DerivedSecretKeyProvider
      autoload :EncryptableRecord
      autoload :EncryptedAttributeType
      autoload :EncryptedFixtures
      autoload :EncryptingOnlyEncryptor
      autoload :DeterministicKeyProvider
      autoload :Encryptor
      autoload :EnvelopeEncryptionKeyProvider
      autoload :Errors
      autoload :ExtendedDeterministicQueries
      autoload :ExtendedDeterministicUniquenessValidator
      autoload :Key
      autoload :KeyGenerator
      autoload :KeyProvider
      autoload :Message
      autoload :MessageSerializer
      autoload :NullEncryptor
      autoload :Properties
      autoload :ReadOnlyNullEncryptor
      autoload :Scheme
    end

    class Cipher
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Aes256Gcm
      end
    end

    include Configurable
    include Contexts

    def self.eager_load!
      super

      Cipher.eager_load!
    end
  end

  ActiveSupport.run_load_hooks :active_record_encryption, Encryption
end
