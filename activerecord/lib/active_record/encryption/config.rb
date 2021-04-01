# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Container of configuration options
    class Config
      attr_accessor :primary_key, :deterministic_key, :store_key_references, :key_derivation_salt,
                    :support_unencrypted_data, :encrypt_fixtures, :validate_column_size, :add_to_filter_parameters,
                    :excluded_from_filter_parameters, :extend_queries, :previous_schemes

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

      private
        def set_defaults
          self.store_key_references = false
          self.support_unencrypted_data = false
          self.encrypt_fixtures = false
          self.validate_column_size = true
          self.add_to_filter_parameters = true
          self.excluded_from_filter_parameters = []
          self.previous_schemes = []

          # TODO: Setting to false for now as the implementation is a bit experimental
          self.extend_queries = false
        end

        def add_previous_scheme(**properties)
          previous_schemes << ActiveRecord::Encryption::Scheme.new(**properties)
        end
    end
  end
end
