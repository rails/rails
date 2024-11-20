# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # An ActiveModel::Type::Value that encrypts/decrypts strings of text.
    #
    # This is the central piece that connects the encryption system with +encrypts+ declarations in the
    # model classes. Whenever you declare an attribute as encrypted, it configures an +EncryptedAttributeType+
    # for that attribute.
    class EncryptedAttributeType < ::ActiveModel::Type::Value
      include ActiveModel::Type::Helpers::Mutable

      attr_reader :scheme, :cast_type

      delegate :key_provider, :downcase?, :deterministic?, :previous_schemes, :with_context, :fixed?, to: :scheme
      delegate :accessor, :type, to: :cast_type

      # === Options
      #
      # * <tt>:scheme</tt> - A +Scheme+ with the encryption properties for this attribute.
      # * <tt>:cast_type</tt> - A type that will be used to serialize (before encrypting) and deserialize
      #   (after decrypting). ActiveModel::Type::String by default.
      def initialize(scheme:, cast_type: ActiveModel::Type::String.new, previous_type: false, default: nil)
        super()
        @scheme = scheme
        @cast_type = cast_type
        @previous_type = previous_type
        @default = default
      end

      def cast(value)
        cast_type.cast(value)
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

      def encrypted?(value)
        with_context { encryptor.encrypted? value }
      end

      def changed_in_place?(raw_old_value, new_value)
        old_value = raw_old_value.nil? ? nil : deserialize(raw_old_value)
        old_value != new_value
      end

      def previous_types # :nodoc:
        @previous_types ||= {} # Memoizing on support_unencrypted_data so that we can tweak it during tests
        @previous_types[support_unencrypted_data?] ||= build_previous_types_for(previous_schemes_including_clean_text)
      end

      def support_unencrypted_data?
        ActiveRecord::Encryption.config.support_unencrypted_data && scheme.support_unencrypted_data? && !previous_type?
      end

      private
        def previous_schemes_including_clean_text
          previous_schemes.including((clean_text_scheme if support_unencrypted_data?)).compact
        end

        def previous_types_without_clean_text
          @previous_types_without_clean_text ||= build_previous_types_for(previous_schemes)
        end

        def build_previous_types_for(schemes)
          schemes.collect do |scheme|
            EncryptedAttributeType.new(scheme: scheme, previous_type: true)
          end
        end

        def previous_type?
          @previous_type
        end

        def decrypt_as_text(value)
          with_context do
            unless value.nil?
              if @default && @default == value
                value
              else
                encryptor.decrypt(value, **decryption_options)
              end
            end
          end
        rescue ActiveRecord::Encryption::Errors::Base => error
          if previous_types_without_clean_text.blank?
            handle_deserialize_error(error, value)
          else
            try_to_deserialize_with_previous_encrypted_types(value)
          end
        end

        def decrypt(value)
          text_to_database_type decrypt_as_text(database_type_to_text(value))
        end

        def try_to_deserialize_with_previous_encrypted_types(value)
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

        def serialize_with_oldest?
          @serialize_with_oldest ||= fixed? && previous_types_without_clean_text.present?
        end

        def serialize_with_oldest(value)
          previous_types.first.serialize(value)
        end

        def serialize_with_current(value)
          casted_value = cast_type.serialize(value)
          casted_value = casted_value&.downcase if downcase?
          encrypt(casted_value.to_s) unless casted_value.nil?
        end

        def encrypt_as_text(value)
          with_context do
            if encryptor.binary? && !cast_type.binary?
              raise Errors::Encoding, "Binary encoded data can only be stored in binary columns"
            end

            encryptor.encrypt(value, **encryption_options)
          end
        end

        def encrypt(value)
          text_to_database_type encrypt_as_text(value)
        end

        def encryptor
          ActiveRecord::Encryption.encryptor
        end

        def encryption_options
          { key_provider: key_provider, cipher_options: { deterministic: deterministic? } }.compact
        end

        def decryption_options
          { key_provider: key_provider }.compact
        end

        def clean_text_scheme
          @clean_text_scheme ||= ActiveRecord::Encryption::Scheme.new(downcase: downcase?, encryptor: ActiveRecord::Encryption::NullEncryptor.new)
        end

        def text_to_database_type(value)
          if value && cast_type.binary?
            ActiveModel::Type::Binary::Data.new(value)
          else
            value
          end
        end

        def database_type_to_text(value)
          if value && cast_type.binary?
            binary_cast_type = cast_type.serialized? ? cast_type.subtype : cast_type
            binary_cast_type.deserialize(value)
          else
            value
          end
        end
    end
  end
end
