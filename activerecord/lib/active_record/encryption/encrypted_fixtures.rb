# frozen_string_literal: true

module ActiveRecord
  module Encryption
    # Encrypts encryptable columns when loading fixtures automatically
    module EncryptedFixtures
      def initialize(fixture, model_class)
        @clean_values = {}
        encrypt_fixture_data(fixture, model_class)
        process_preserved_original_columns(fixture, model_class)
        super
      end

      private
        def encrypt_fixture_data(fixture, model_class)
          model_class&.encrypted_attributes&.each do |attribute_name|
            if clean_value = fixture[attribute_name.to_s]
              @clean_values[attribute_name.to_s] = clean_value

              type = model_class.type_for_attribute(attribute_name)
              encrypted_value = type.serialize(clean_value)
              fixture[attribute_name.to_s] = encrypted_value
            end
          end
        end

        def process_preserved_original_columns(fixture, model_class)
          model_class&.encrypted_attributes&.each do |attribute_name|
            if source_attribute_name = model_class.source_attribute_from_preserved_attribute(attribute_name)
              clean_value = @clean_values[source_attribute_name.to_s]
              type = model_class.type_for_attribute(attribute_name)
              encrypted_value = type.serialize(clean_value)
              fixture[attribute_name.to_s] = encrypted_value
            end
          end
        end
    end
  end
end
