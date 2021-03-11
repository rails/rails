# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # An +ActiveModel::Type+ that encrypts/decrypts strings of text
    #
    # This is the central piece that connects the encryption system with +encrypts+ declarations in the
    # model classes. Whenever you declare an attribute as encrypted, it configures an +EncryptedAttributeType+
    # for that attribute.
    class EncryptedAttributeType < ::ActiveRecord::Type::Text
      include ActiveModel::Type::Helpers::Mutable

      attr_reader :key_provider, :previous_types, :subtype, :downcase

      def initialize(key_provider: nil, deterministic: false, downcase: false, subtype: ActiveModel::Type::String.new, previous_types: [], **context_properties)
        super()
        @key_provider = key_provider
        @deterministic = deterministic
        @downcase = downcase
        @subtype = subtype
        @previous_types = previous_types
        @context_properties = context_properties
      end

      def deserialize(value)
        @subtype.deserialize decrypt(value)
      end

      def serialize(value)
        casted_value = @subtype.serialize(value)
        casted_value = casted_value&.downcase if @downcase
        encrypt(casted_value.to_s) unless casted_value.nil? # Object values without a proper serializer get converted with #to_s
      end

      def changed_in_place?(raw_old_value, new_value)
        old_value = raw_old_value.nil? ? nil : deserialize(raw_old_value)
        old_value != new_value
      end

      def deterministic?
        @deterministic
      end

      def additional_encrypted_types # :nodoc:
        if support_unencrypted_data?
          @previous_types_with_clean_text_type ||= previous_types.including(clean_text_type)
        else
          previous_types
        end
      end

      private
        def decrypt(value)
          with_context do
            encryptor.decrypt(value, **decryption_options) unless value.nil?
          end
        rescue ActiveRecord::Encryption::Errors::Base => error
          if previous_types.blank?
            handle_deserialize_error(error, value)
          else
            try_to_deserialize_with_previous_types(value)
          end
        end

        def try_to_deserialize_with_previous_types(value)
          previous_types.each.with_index do |type, index|
            break type.deserialize(value)
          rescue ActiveRecord::Encryption::Errors::Base => error
            handle_deserialize_error(error, value) if index == previous_types.length - 1
          end
        end

        def handle_deserialize_error(error, value)
          if error.is_a?(Errors::Decryption) && support_unencrypted_data?
            value
          else
            raise error
          end
        end

        def support_unencrypted_data?
          ActiveRecord::Encryption.config.support_unencrypted_data
        end

        def encrypt(value)
          with_context do
            encryptor.encrypt(value, **encryption_options)
          end
        end

        def encryptor
          ActiveRecord::Encryption.encryptor
        end

        def encryption_options
          @encryption_options ||= { key_provider: @key_provider, cipher_options: { deterministic: @deterministic } }.compact
        end

        def decryption_options
          @decryption_options ||= { key_provider: @key_provider }.compact
        end

        def with_context(&block)
          if @context_properties.present?
            ActiveRecord::Encryption.with_encryption_context(**@context_properties, &block)
          else
            block.call
          end
        end

        def clean_text_type
          @clean_text_type ||= ActiveRecord::Encryption::EncryptedAttributeType.new(downcase: downcase, encryptor: ActiveRecord::Encryption::NullEncryptor.new)
        end
    end
  end
end
