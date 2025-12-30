# frozen_string_literal: true

# :markup: markdown

module ActionText
  module Encryption
    def encrypt
      transaction do
        super
        encrypt_rich_texts if has_encrypted_rich_texts?
      end
    end

    def decrypt
      transaction do
        super
        decrypt_rich_texts if has_encrypted_rich_texts?
      end
    end

    private
      def encrypt_rich_texts
        encryptable_rich_texts.each(&:encrypt)
      end

      def decrypt_rich_texts
        encryptable_rich_texts.each(&:decrypt)
      end

      def has_encrypted_rich_texts?
        encryptable_rich_texts.present?
      end

      def encryptable_rich_texts
        @encryptable_rich_texts ||= self.class.rich_text_association_names
          .filter_map { |attribute_name| send(attribute_name) }
          .find_all { |record| record.is_a?(ActionText::EncryptedRichText) }
      end
  end
end
