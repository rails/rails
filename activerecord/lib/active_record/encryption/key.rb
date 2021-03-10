# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A key is a container for a given +secret+
    #
    # Optionally, it can include +public_tags+. These tags are meant to be stored
    # in clean (public) and can be used, for example, to include information that
    # references the key for a future retrieval operation.
    class Key
      attr_reader :secret, :public_tags

      def initialize(secret)
        @secret = secret
        @public_tags = Properties.new
      end

      def self.derive_from(password)
        secret = ActiveRecord::Encryption.key_generator.derive_key_from(password)
        ActiveRecord::Encryption::Key.new(secret)
      end

      def id
        Digest::SHA1.hexdigest(secret).first(4)
      end
    end
  end
end
