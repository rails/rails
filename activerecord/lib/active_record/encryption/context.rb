# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # An encryption context configures the different entities used to perform encryption:
    #
    # * A key provider
    # * A key generator
    # * An encryptor, the facade to encrypt data
    # * A cipher, the encryption algorithm
    # * A message serializer
    class Context
      PROPERTIES = %i[ key_provider key_generator cipher message_serializer encryptor frozen_encryption ]

      attr_accessor(*PROPERTIES)

      def initialize
        set_defaults
      end

      alias frozen_encryption? frozen_encryption

      silence_redefinition_of_method :key_provider
      def key_provider
        @key_provider ||= build_default_key_provider
      end

      private
        def set_defaults
          self.frozen_encryption = false
          self.key_generator = ActiveRecord::Encryption::KeyGenerator.new
          self.cipher = ActiveRecord::Encryption::Cipher.new
          self.encryptor = ActiveRecord::Encryption::Encryptor.new
          self.message_serializer = ActiveRecord::Encryption::MessageSerializer.new
        end

        def build_default_key_provider
          ActiveRecord::Encryption::DerivedSecretKeyProvider.new(ActiveRecord::Encryption.config.primary_key)
        end
    end
  end
end
