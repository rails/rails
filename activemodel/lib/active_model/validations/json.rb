module ActiveModel
  module Validations
    class JsonValidator < ActiveModel::EachValidator
      attr_accessor :record, :attribute, :attribute_value

      def validate_each(record, attribute, attribute_value)
        self.record = record
        self.attribute = attribute
        self.attribute_value = attribute_value

        options.each do |key, value|
          # Find and execute the sub validator methods
          # for each key in the <tt>options</tt> hash.
          send("#{key}_validator", value) if respond_to? "#{key}_validator"
        end
      end

      # Check whether that record include each of given fields
      def include_validator(fields)
        if fields.respond_to? :each
          fields.each do |key|
            if attribute_value.kind_of?(Hash) && !attribute_value.include?(key.to_s)
              add_error "'#{attribute}' does not contains '#{key}'"
            end
          end
        end
      end

      private

      def add_error(msg)
        record.errors[attribute] << (options[:message] || msg || 'is invalid')
      end
    end

    module HelperMethods
      # Validate whether the given <tt>json</tt> field meets specified
      # standard or not. For example:
      #
      #   class Person < ActiveRecord::Base
      #     validates_json_of :contact, include: [:phone_number]
      #   end
      #
      # The above example will ensure that <tt>contact</tt> field contains
      # a <tt>phone_number</tt> key.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message. (default is: "is invalid").
      # * <tt>:include</tt> - An array of keys with given <tt>json</tt> data
      # should include.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_json_of(*attr_names)
        validates_with JsonValidator, _merge_attributes(attr_names)
      end
    end

  end
end
