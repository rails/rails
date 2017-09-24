# frozen_string_literal: true

module ActiveSupport
  module Messages
    module Rotator # :nodoc:
      def initialize(*, **options)
        super

        @options   = options
        @rotations = []
      end

      def rotate(*args)
        @rotations << create_rotation(*args)
      end

      module Encryptor
        include Rotator

        def decrypt_and_verify(*args, on_rotation: nil, **options)
          super
        rescue MessageEncryptor::InvalidMessage, MessageVerifier::InvalidSignature
          run_rotations(on_rotation) { |encryptor| encryptor.decrypt_and_verify(*args, options) } || raise
        end

        private
          def create_rotation(raw_key: nil, raw_signed_key: nil, **options)
            options[:cipher] ||= @cipher

            self.class.new \
              raw_key || extract_key(options),
              raw_signed_key || extract_signing_key(options),
              @options.merge(options.slice(:cipher, :digest, :serializer))
          end

          def extract_key(cipher:, salt:, key_generator: nil, secret: nil, **)
            key_generator ||= key_generator_for(secret)
            key_generator.generate_key(salt, self.class.key_len(cipher))
          end

          def extract_signing_key(cipher:, signed_salt: nil, key_generator: nil, secret: nil, **)
            if cipher.downcase.end_with?("cbc")
              raise ArgumentError, "missing signed_salt for signing key generation" unless signed_salt

              key_generator ||= key_generator_for(secret)
              key_generator.generate_key(signed_salt)
            end
          end
      end

      module Verifier
        include Rotator

        def verified(*args, on_rotation: nil, **options)
          super || run_rotations(on_rotation) { |verifier| verifier.verified(*args, options) }
        end

        private
          def create_rotation(raw_key: nil, **options)
            self.class.new(raw_key || extract_key(options), @options.merge(options.slice(:digest, :serializer)))
          end

          def extract_key(key_generator: nil, secret: nil, salt:)
            key_generator ||= key_generator_for(secret)
            key_generator.generate_key(salt)
          end
      end

      private
        def key_generator_for(secret)
          ActiveSupport::KeyGenerator.new(secret, iterations: 1000)
        end

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
