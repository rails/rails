# frozen_string_literal: true

module ActiveSupport
  module Messages
    module Rotator # :nodoc:
      def initialize(*, **options)
        super

        @options   = options
        @rotations = []
      end

      def rotate(*secrets, **options)
        @rotations << build_rotation(*secrets, @options.merge(options))
      end

      module Encryptor
        include Rotator

        def decrypt_and_verify(*args, on_rotation: nil, **options)
          super
        rescue MessageEncryptor::InvalidMessage, MessageVerifier::InvalidSignature
          run_rotations(on_rotation) { |encryptor| encryptor.decrypt_and_verify(*args, options) } || raise
        end

        private
          def build_rotation(secret = @secret, sign_secret = @sign_secret, options)
            self.class.new(secret, sign_secret, options)
          end
      end

      module Verifier
        include Rotator

        def verified(*args, on_rotation: nil, **options)
          super || run_rotations(on_rotation) { |verifier| verifier.verified(*args, options) }
        end

        private
          def build_rotation(secret = @secret, options)
            self.class.new(secret, options)
          end
      end

      private
        def run_rotations(on_rotation)
          @rotations.find do |rotation|
            if message = yield(rotation) rescue next
              on_rotation.call if on_rotation
              return message
            end
          end
        end
    end
  end
end
