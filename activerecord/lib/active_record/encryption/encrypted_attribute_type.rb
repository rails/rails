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

      delegate :key_provider, :downcase?, :deterministic?, :with_context, :fixed?, to: :scheme

      # === Options
      #
      # * <tt>:scheme</tt> - An +Scheme+ with the encryption properties for this attribute.
      # * <tt>:cast_type</tt> - A type that will be used to serialize (before encrypting) and deserialize
      #   (after decrypting). +ActiveModel::Type::String+ by default.
      def initialize(scheme:, cast_type: ActiveModel::Type::String.new, previous_type: false)
        super()
        @scheme = scheme
        @cast_type = cast_type
        @previous_type = previous_type
      end

      def deserialize(value)
        cast_type.deserialize decrypt(value)
      end

      def serialize(value)
        if serialize_with_oldest?
          serialize_with_oldest(value)
        else
          serialize_with_current(value)
        end
      end

      def changed_in_place?(raw_old_value, new_value)
        old_value = raw_old_value.nil? ? nil : deserialize(raw_old_value)
        old_value != new_value
      end

      def previous_encrypted_types(include_clear: true) # :nodoc:
        @previous_encrypted_types ||= {} # Memoizing on support_unencrypted_data so that we can tweak it during tests
        @previous_encrypted_types["#{support_unencrypted_data?} #{include_clear}"] ||= previous_schemes(include_clear: include_clear).collect do |scheme|
          EncryptedAttributeType.new(scheme: scheme, previous_type: true)
        end
      end

      private
        def previous_type?
          @previous_type
        end

        def serialize_with_oldest?
          @serialize_with_oldest ||= fixed? && previous_encrypted_types(include_clear: false).present?
        end

        def serialize_with_oldest(value)
          previous_encrypted_types.first.serialize(value)
        end

        def serialize_with_current(value)
          casted_value = cast_type.serialize(value)
          casted_value = casted_value&.downcase if downcase?
          encrypt(casted_value.to_s) unless casted_value.nil?
        end

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
            handle_deserialize_error(error, value) if index == previous_encrypted_types(include_clear: true).length - 1
          end
        end

        def handle_deserialize_error(error, value)
          if error.is_a?(Errors::Decryption) && support_unencrypted_data?
            value
          else
            raise error
          end
        end

        def previous_schemes(include_clear: true)
          scheme.previous_schemes.including((clean_text_scheme if include_clear && support_unencrypted_data?)).compact
        end

        def support_unencrypted_data?
          ActiveRecord::Encryption.config.support_unencrypted_data && !previous_type?
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

        def clean_text_scheme
          @clean_text_scheme ||= ActiveRecord::Encryption::Scheme.new(downcase: downcase?, encryptor: ActiveRecord::Encryption::NullEncryptor.new)
        end
    end
  end
end
