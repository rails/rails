# frozen_string_literal: true

module ActiveSupport
  module Messages
    module Rotator # :nodoc:
      def initialize(*secrets, on_rotation: nil, **options)
        super(*secrets, **options)

        @secrets = secrets
        @options = options
        @rotations = []
        @on_rotation = on_rotation
      end

      def rotate(*secrets, **options)
        fall_back_to build_rotation(*secrets, **options)
      end

      def fall_back_to(fallback)
        @rotations << fallback
        self
      end

      module Encryptor # :nodoc:
        include Rotator

        def decrypt_and_verify(*args, on_rotation: @on_rotation, **options)
          super
        rescue MessageEncryptor::InvalidMessage, MessageVerifier::InvalidSignature
          run_rotations(on_rotation) { |encryptor| encryptor.decrypt_and_verify(*args, **options) } || raise
        end
      end

      module Verifier # :nodoc:
        include Rotator

        def verified(*args, on_rotation: @on_rotation, **options)
          super || run_rotations(on_rotation) { |verifier| verifier.verified(*args, **options) }
        end
      end

      private
        def build_rotation(*secrets, **options)
          self.class.new(*secrets, *@secrets.drop(secrets.length), **@options, **options)
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
