# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # A container of attribute encryption options.
    #
    # It validates and serves attribute encryption options.
    #
    # See +EncryptedAttributeType+, +Context+
    class Scheme
      attr_reader :previous_schemes

      def initialize(key_provider: nil, key: nil, deterministic: false, downcase: false, ignore_case: false,
                     previous_schemes: [], **context_properties)
        @key_provider_param = key_provider
        @key = nil
        @deterministic = deterministic
        @downcase = downcase || ignore_case
        @ignore_case = ignore_case
        @previous_schemes = previous_schemes
        @context_properties = context_properties

        validate!
      end

      def ignore_case?
        @ignore_case
      end

      def downcase?
        @downcase
      end

      def deterministic?
        @deterministic
      end

      def key_provider
        @key_provider ||= @key_provider_param || build_key_provider
      end

      def with_context(&block)
        if @context_properties.present?
          ActiveRecord::Encryption.with_encryption_context(**@context_properties, &block)
        else
          block.call
        end
      end

      private
        def validate!
          raise Errors::Configuration, ":ignore_case can only be used with deterministic encryption" if @ignore_case && !@deterministic
          raise Errors::Configuration, ":key_provider and :key can't be used simultaneously" if @key_provider_param && @key
        end

        def build_key_provider
          return DerivedSecretKeyProvider.new(@key) if @key.present?

          if @deterministic && (deterministic_key = ActiveRecord::Encryption.config.deterministic_key)
            DerivedSecretKeyProvider.new(deterministic_key)
          end
        end
    end
  end
end
