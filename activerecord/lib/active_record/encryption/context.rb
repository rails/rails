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

      PROPERTIES.each do |name|
        attr_accessor name
      end

      def initialize
        set_defaults
      end

      alias frozen_encryption? frozen_encryption

      private
        def set_defaults
          self.frozen_encryption = false
          self.key_generator = ActiveRecord::Encryption::KeyGenerator.new
          self.cipher = ActiveRecord::Encryption::Cipher.new
          self.encryptor = ActiveRecord::Encryption::Encryptor.new
          self.message_serializer = ActiveRecord::Encryption::MessageSerializer.new
        end
    end
  end
end
