# frozen_string_literal: true

require_relative "extensions"

module ActiveSupport
  module MessagePack
    module Serializer # :nodoc:
      SIGNATURE = "\xCC\x80".b.freeze # == 128.to_msgpack
      SIGNATURE_INT = 128

      def dump(object)
        message_pack_pool.packer do |packer|
          packer.write(SIGNATURE_INT)
          packer.write(object)
          packer.full_pack
        end
      end

      def load(dumped)
        message_pack_pool.unpacker do |unpacker|
          unpacker.feed_reference(dumped)
          raise "Invalid serialization format" unless unpacker.read == SIGNATURE_INT
          unpacker.full_unpack
        end
      end

      def signature?(dumped)
        dumped.getbyte(0) == SIGNATURE.getbyte(0) && dumped.getbyte(1) == SIGNATURE.getbyte(1)
      end

      def message_pack_factory
        @message_pack_factory ||= ::MessagePack::Factory.new
      end

      def message_pack_factory=(factory)
        @message_pack_pool = nil
        @message_pack_factory = factory
      end

      delegate :register_type, to: :message_pack_factory

      def warmup
        message_pack_pool # eagerly compute
      end

      private
        def message_pack_pool
          @message_pack_pool ||= begin
            unless message_pack_factory.frozen?
              Extensions.install(message_pack_factory)
              install_unregistered_type_handler
              message_pack_factory.freeze
            end
            message_pack_factory.pool(ENV.fetch("RAILS_MAX_THREADS", 5).to_i)
          end
        end

        def install_unregistered_type_handler
          Extensions.install_unregistered_type_error(message_pack_factory)
        end
    end
  end
end
