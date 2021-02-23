module ActiveRecord
  module Encryption
    # Container of contfiguration options
    class Config
      attr_accessor :master_key, :deterministic_key, :store_key_references, :key_derivation_salt,
                    :support_unencrypted_data, :encrypt_fixtures, :validate_column_size, :add_to_filter_parameters,
                    :excluded_from_filter_parameters

      def initialize
        set_defaults
      end

      private
        def set_defaults
          self.store_key_references = false
          self.support_unencrypted_data = false
          self.encrypt_fixtures = false
          self.validate_column_size = true
          self.add_to_filter_parameters = true
          self.excluded_from_filter_parameters = []
        end
    end
  end
end
