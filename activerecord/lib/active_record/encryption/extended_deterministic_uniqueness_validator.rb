# frozen_string_literal: true

module ActiveRecord
  module Encryption
    module ExtendedDeterministicUniquenessValidator
      def self.install_support
        ActiveRecord::Validations::UniquenessValidator.prepend(EncryptedUniquenessValidator)
      end

      module EncryptedUniquenessValidator
        def validate_each(record, attribute, value)
          super(record, attribute, value)

          klass = record.class
          if klass.deterministic_encrypted_attributes&.include?(attribute)
            encrypted_type = klass.type_for_attribute(attribute)
            encrypted_type.previous_types.each do |type|
              # Wrapping the value keeps the attribute's type from processing the result again
              # while the relation is built. +without_encryption+ alone only stops it from being
              # encrypted twice; a normalization declared with +normalizes+ would still be applied
              # to the ciphertext and corrupt it.
              super(record, attribute, ExtendedDeterministicQueries::AdditionalValue.new(value, type))
            end
          end
        end
      end
    end
  end
end
