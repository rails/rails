# frozen_string_literal: true

require_relative "serializer"

module ActiveSupport
  module MessagePack
    module CacheSerializer
      include Serializer
      extend self

      def load(dumped)
        super
      rescue ActiveSupport::MessagePack::MissingClassError
        # Treat missing class as cache miss => return nil
      end

      private
        def install_unregistered_type_handler
          Extensions.install_unregistered_type_fallback(message_pack_factory)
        end
    end
  end
end
