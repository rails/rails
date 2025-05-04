# frozen_string_literal: true

module ActiveModel
  module Validations
    class UniquenessAmongValidator < EachValidator # :nodoc:
      DEFAULTS = { case_sensitive: true }.freeze

      def initialize(options)
        super(DEFAULTS.merge(options))
      end

      def validate_each(record, attribute, value)
        return if value.blank? && options[:allow_blank]
        return if value.nil? && options[:allow_nil]

        other_attributes = Array(options[:in] || options[:within] || attributes) - [attribute]
        return if other_attributes.empty?

        duplicates = []
        other_attributes.each do |attr|
          other_value = record.public_send(attr)
          next if other_value.nil? && options[:allow_nil]
          next if other_value.blank? && options[:allow_blank]

          if value_equal?(value, other_value)
            duplicates << attr
          end
        end

        if duplicates.any?
          error_options = options.except(:case_sensitive, :in, :within, :compare_hash_keys_as_strings).merge!(
            value: value,
            attributes: duplicates.join(", ")
          )
          record.errors.add(attribute, :taken_among, **error_options)
        end
      end

      private
        def value_equal?(value, other_value)
          if !options[:case_sensitive] && value.is_a?(String) && other_value.is_a?(String)
            value.casecmp(other_value) == 0
          elsif value.is_a?(Array) && other_value.is_a?(Array)
            return false if value.size != other_value.size
            sorted_value = value.sort rescue value
            sorted_other = other_value.sort rescue other_value
            sorted_value == sorted_other
          elsif value.is_a?(Hash) && other_value.is_a?(Hash)
            return false if value.size != other_value.size

            if options[:compare_hash_keys_as_strings]
              # Convert all keys to strings for comparison
              normalized_value = normalize_hash_keys(value)
              normalized_other = normalize_hash_keys(other_value)
              normalized_value == normalized_other
            else
              # Compare as-is but sort to handle different insertion orders
              value.to_a.sort_by { |k, _| k.to_s } == other_value.to_a.sort_by { |k, _| k.to_s }
            end
          else
            value == other_value
          end
        end

        def normalize_hash_keys(hash)
          result = {}
          hash.each do |k, v|
            key = k.to_s
            value = v.is_a?(Hash) ? normalize_hash_keys(v) : v
            result[key] = value
          end
          result
        end
    end

    module HelperMethods
      # Validates that the attribute is unique among a set of attributes within the same object.
      #
      #   class Person < ActiveRecord::Base
      #     # Validates that primary and secondary emails are different
      #     validates_uniqueness_of_among :primary_email, :secondary_email
      #
      #     # Validates that all phone numbers are unique
      #     validates_uniqueness_of_among :home_phone, :work_phone, :mobile_phone,
      #                                   message: "must be different from other phone numbers"
      #
      #     # Validates that all tag sets are unique
      #     validates_uniqueness_of_among :primary_tags, :secondary_tags
      #
      #     # Validates that metadata fields are unique, treating string and symbol keys as equivalent
      #     validates_uniqueness_of_among :primary_metadata, :secondary_metadata,
      #                                   compare_hash_keys_as_strings: true
      #   end
      #
      # === Special data types
      #
      # The validator handles different data types with special considerations:
      #
      # * Strings: Can be compared with or without case sensitivity
      # * Arrays: Compared by content regardless of element order
      # * Hashes: Compared by content regardless of key order
      # * Nested structures: Hash values containing other hashes are compared recursively
      #
      # This makes the validator particularly useful for:
      #
      # * Multilingual content stored in hashes like +{en: "Title", es: "Título"}+
      # * Tag lists or category arrays that should not duplicate across fields
      # * Multiple contact information fields that should contain unique values
      #
      # === Configuration options
      # * <tt>:message</tt> - A custom error message (default is: "has already been taken among %{attributes}").
      #   The message can include %{attributes} which will be replaced with the names of the duplicated attributes.
      # * <tt>:case_sensitive</tt> - Looks for an exact match for string comparisons. Default is +true+.
      # * <tt>:allow_nil</tt> - If set to +true+, skips this validation if the attribute is +nil+ (default is +false+).
      # * <tt>:allow_blank</tt> - If set to +true+, skips this validation if the attribute is blank (default is +false+).
      # * <tt>:in</tt> or <tt>:within</tt> - Specifies an array of attributes to check against.
      # * <tt>:compare_hash_keys_as_strings</tt> - When +true+, hash keys are compared as strings,
      #   so <tt>{ a: 1 }</tt> and <tt>{ "a" => 1 }</tt> are considered equal. Default is +false+.
      #
      # For array attributes, the validator checks if the arrays contain the same elements,
      # regardless of their order. Similarly, for hash attributes, the validator checks if
      # the hashes contain the same key-value pairs, regardless of internal ordering.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See ActiveModel::Validations::ClassMethods#validates for more information.
      def validates_uniqueness_of_among(*attr_names)
        validates_with UniquenessAmongValidator, _merge_attributes(attr_names)
      end
    end
  end
end
