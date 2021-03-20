# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # An +ActiveModel::Type+ that encrypts/decrypts strings of text.
    #
    # This is the central piece that connects the encryption system with +encrypts+ declarations in the
    # model classes. Whenever you declare an attribute as encrypted, it configures an +EncryptedAttributeType+
    # for that attribute.
    class EncryptedAttributeType < ::ActiveRecord::Type::Text
      include ActiveModel::Type::Helpers::Mutable

      attr_reader :scheme, :cast_type

      delegate :key_provider, :previous_encrypted_types, :downcase?, :deterministic?, :with_context, to: :scheme

      # === Options
      #
      # * <tt>:scheme</tt> - An +Scheme+ with the encryption properties for this attribute.
      # * <tt>:cast_type</tt> - A type that will be used to serialize (before encrypting) and deserialize
      #   (after decrypting). +ActiveModel::Type::String+ by default.
      def initialize(scheme:, cast_type: ActiveModel::Type::String.new)
        super()
        @scheme = scheme
        @cast_type = cast_type
      end

      def deserialize(value)
        cast_type.deserialize decrypt(value)
      end

      def serialize(value)
        casted_value = cast_type.serialize(value)
        casted_value = casted_value&.downcase if downcase?
        encrypt(casted_value.to_s) unless casted_value.nil? # Object values without a proper serializer get converted with #to_s
      end

      def changed_in_place?(raw_old_value, new_value)
        old_value = raw_old_value.nil? ? nil : deserialize(raw_old_value)
        old_value != new_value
      end

      def additional_encrypted_types # :nodoc:
        if support_unencrypted_data?
          @previous_encrypted_types_with_clean_text_type ||= previous_encrypted_types.including(clean_text_type)
        else
          previous_encrypted_types
        end
      end

      private
        def decrypt(value)
          with_context do
            encryptor.decrypt(value, **decryption_options) unless value.nil?
          end
        rescue ActiveRecord::Encryption::Errors::Base => error
          if previous_encrypted_types.blank?
            handle_deserialize_error(error, value)
          else
            try_to_deserialize_with_previous_encrypted_types(value)
          end
        end

        def try_to_deserialize_with_previous_encrypted_types(value)
          previous_encrypted_types.each.with_index do |type, index|
            break type.deserialize(value)
          rescue ActiveRecord::Encryption::Errors::Base => error
            handle_deserialize_error(error, value) if index == previous_encrypted_types.length - 1
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
          @encryption_options ||= { key_provider: key_provider, cipher_options: { deterministic: deterministic? } }.compact
        end

        def decryption_options
          @decryption_options ||= { key_provider: key_provider }.compact
        end

        def clean_text_type
          @clean_text_type ||= begin
            config = ActiveRecord::Encryption::Scheme.new(downcase: downcase?, encryptor: ActiveRecord::Encryption::NullEncryptor.new)
            ActiveRecord::Encryption::EncryptedAttributeType.new(scheme: config)
          end
        end
    end
  end
end
