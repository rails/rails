module ActiveRecord
  module Encryption
    # A +KeyProvider+ serves keys:
    #
    # * An encryption key
    # * A list of potential decryption keys. Serving multiple decryption keys supports rotation-schemes
    #   where new keys are added but old keys need to continue working
    class KeyProvider
      def initialize(keys)
        @keys = Array(keys)
      end

      # Returns the first key in the list as the active key to perform encryptions
      #
      # When +ActiveRecord::Encryption.config.store_key_references+ is true, the key will include
      # a public tag referencing the key itself. That key will be stored in the public
      # headers of the encrypted message
      def encryption_key
        @encryption_key ||= @keys.first.tap do |key|
          key.public_tags.encrypted_data_key_id = key.id if ActiveRecord::Encryption.config.store_key_references
        end
      end

      # Returns the list of decryption keys
      #
      # When the message holds a reference to its encryption key, it will return an array
      # with that key. If not, it will return the list of keys.
      def decryption_keys(encrypted_message)
        if encrypted_message.headers.encrypted_data_key_id
          keys_grouped_by_id[encrypted_message.headers.encrypted_data_key_id]
        else
          @keys
        end
      end

      private
        def keys_grouped_by_id
          @keys_grouped_by_id ||= @keys.group_by(&:id)
        end
    end
  end
end
