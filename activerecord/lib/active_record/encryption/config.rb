# frozen_string_literal: true

require "openssl"

module ActiveRecord
  module Encryption
    # Container of configuration options
    class Config
      attr_accessor :primary_key, :deterministic_key, :store_key_references, :key_derivation_salt, :hash_digest_class,
                    :support_unencrypted_data, :encrypt_fixtures, :validate_column_size, :add_to_filter_parameters,
                    :excluded_from_filter_parameters, :extend_queries, :previous_schemes, :forced_encoding_for_deterministic_encryption,
                    :compressor

      def initialize
        set_defaults
      end

      # Configure previous encryption schemes.
      #
      #   config.active_record.encryption.previous = [ { key_provider: MyOldKeyProvider.new } ]
      def previous=(previous_schemes_properties)
        previous_schemes_properties.each do |properties|
          add_previous_scheme(**properties)
        end
      end

      def support_sha1_for_non_deterministic_encryption=(value)
        if value && has_primary_key?
          sha1_key_generator = ActiveRecord::Encryption::KeyGenerator.new(hash_digest_class: OpenSSL::Digest::SHA1)
          sha1_key_provider = ActiveRecord::Encryption::DerivedSecretKeyProvider.new(primary_key, key_generator: sha1_key_generator)
          add_previous_scheme key_provider: sha1_key_provider
        end
      end

      %w(key_derivation_salt primary_key deterministic_key).each do |key|
        silence_redefinition_of_method "has_#{key}?"
        define_method("has_#{key}?") do
          instance_variable_get(:"@#{key}").presence
        end

        silence_redefinition_of_method key
        define_method(key) do
          public_send("has_#{key}?") or
            raise Errors::Configuration, "Missing Active Record encryption credential: active_record_encryption.#{key}"
        end
      end

      private
        def set_defaults
          self.store_key_references = false
          self.support_unencrypted_data = false
          self.encrypt_fixtures = false
          self.validate_column_size = true
          self.add_to_filter_parameters = true
          self.excluded_from_filter_parameters = []
          self.previous_schemes = []
          self.forced_encoding_for_deterministic_encryption = Encoding::UTF_8
          self.hash_digest_class = OpenSSL::Digest::SHA1
          self.compressor = Zlib

          # TODO: Setting to false for now as the implementation is a bit experimental
          self.extend_queries = false
        end

        def add_previous_scheme(**properties)
          previous_schemes << ActiveRecord::Encryption::Scheme.new(**properties)
        end
    end
  end
end
