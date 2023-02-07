# frozen_string_literal: true

module ActiveSupport
  module Messages
    module Rotator # :nodoc:
      def initialize(*args, on_rotation: nil, **options)
        super(*args, **options)
        @args = args
        @options = options
        @rotations = []
        @on_rotation = on_rotation
      end

      def rotate(*args, **options)
        fall_back_to build_rotation(*args, **options)
      end

      def fall_back_to(fallback)
        @rotations << fallback
        self
      end

      module Encryptor # :nodoc:
        include Rotator

        def decrypt_and_verify(message, on_rotation: @on_rotation, **options)
          super(message, **options)
        rescue MessageEncryptor::InvalidMessage, MessageVerifier::InvalidSignature
          run_rotations(on_rotation) { |encryptor| encryptor.decrypt_and_verify(message, **options) } || raise
        end
      end

      module Verifier # :nodoc:
        include Rotator

        def verified(message, on_rotation: @on_rotation, **options)
          super(message, **options) || run_rotations(on_rotation) { |verifier| verifier.verified(message, **options) }
        end
      end

      private
        def build_rotation(*args, **options)
          self.class.new(*args, *@args.drop(args.length), **@options, **options)
        end

        def run_rotations(on_rotation)
          @rotations.find do |rotation|
            if message = yield(rotation) rescue next
              on_rotation&.call
              return message
            end
          end
        end
    end
  end
end
