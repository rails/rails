# frozen_string_literal: true

require "active_support/core_ext/module"
require "active_support/core_ext/array"

module ActiveRecord
  module Encryption
    extend ActiveSupport::Autoload

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
    autoload :Encryptor
    autoload :EnvelopeEncryptionKeyProvider
    autoload :Errors
    autoload :ExtendedDeterministicQueries
    autoload :Key
    autoload :KeyGenerator
    autoload :KeyProvider
    autoload :MassEncryption
    autoload :Message
    autoload :MessageSerializer
    autoload :NullEncryptor
    autoload :Properties
    autoload :ReadOnlyNullEncryptor

    class Cipher
      extend ActiveSupport::Autoload
      autoload :Aes256Gcm
    end

    include Configurable, Contexts
  end
end
