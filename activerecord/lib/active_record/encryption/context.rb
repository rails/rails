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
      attr_accessor :non_defaults # :nodoc:

      def initialize
        set_defaults
      end

      alias frozen_encryption? frozen_encryption

      silence_redefinition_of_method :key_provider
      def key_provider
        @key_provider ||= build_default_key_provider
      end

      def to_h # :nodoc:
        PROPERTIES.index_with { |property| instance_variable_get("@#{property}") }.freeze
      end

      def merge(other) # :nodoc:
        assign_properties(other.to_h.except(*non_defaults.keys))
      end

      def assign_properties(properties) # :nodoc:
        properties.each do |property, value|
          public_send("#{property}=", value)

          non_defaults[property] = value
        end
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
