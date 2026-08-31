# frozen_string_literal: true

module ActiveRecord
  module Encryption
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
              fixture[attribute_name.to_s] = encrypt(model_class, attribute_name, clean_value)
            end
          end
        end

        def process_preserved_original_columns(fixture, model_class)
          model_class&.encrypted_attributes&.each do |attribute_name|
            if source_attribute_name = model_class.source_attribute_from_preserved_attribute(attribute_name)
              clean_value = @clean_values[source_attribute_name.to_s]
              fixture[attribute_name.to_s] = encrypt(model_class, attribute_name, clean_value)
            end
          end
        end

        def encrypt(model_class, attribute_name, clean_value)
          encrypted_value = model_class.type_for_attribute(attribute_name).serialize(clean_value)

          if column = model_class.columns_hash[attribute_name.to_s]
            column.cast_type.deserialize(encrypted_value)
          else
            encrypted_value
          end
        end
    end
  end
end
