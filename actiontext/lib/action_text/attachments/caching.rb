# frozen_string_literal: true

module ActionText
  module Attachments
    module Caching
      def cache_key(*args)
        [self.class.name, cache_digest, *attachable.cache_key(*args)].join("/")
      end

      private
        def cache_digest
          OpenSSL::Digest::SHA256.hexdigest(node.to_s)
        end
    end
  end
end
