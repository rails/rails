module ActiveModel
  module Validations
    class JsonValidator < ActiveModel::EachValidator
      attr_accessor :record, :attribute, :attribute_value

      def validate_each(record, attribute, attribute_value)

        # Check for valid atribute values.
        if !attribute_value.kind_of?(Hash) || !attribute_value.kind_of?(Array)
          raise TypeError, "JsonValidator can be used by 'json' type only"
        end

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
      def include_validator(fields, attr_value = attribute_value)
        if fields.respond_to? :each
          fields.each do |key|
            if attr_value.kind_of?(Hash) && !attr_value.include?(key.to_s)
              add_error "'#{attribute}' does not contains '#{key}'"
            end
          end
        end
      end

      # Check for formats of a specific keys
      def format_validator(opts, attr_value = attribute_value)
        with_hash :format, opts do
          opts.each do |field, format_opts|

            regexp = format_opts[:with]
            value  = attr_value[field].to_s

            unless regexp
              raise ArgumentError, "'with' argument is missing for 'format'."
            end

            add_error "'#{field}' is not well formatted." if value !~ regexp
          end
        end
      end

      # In case of an Array as json root object, <tt>:each</tt>
      # Allow to provide validate options for each element in
      # the given Array.
      def each_validator(opts)
        if attribute_value.respond_to? :each
          attribute_value.each do |json_obj|

            # Skip if current element is not an object
            next unless json_obj.kind_of? Hash

            # Loop over <tt>:each</tt> options and match them
            # against current value.
            with_hash :each, opts do |opt_key, opt_value|
              if respond_to? "#{opt_key}_validator"
                send("#{opt_key}_validator", opt_value, json_obj)
              end
            end

          end
        end
      end

      private

      def with_hash(opt_name, opts, &block)
        if opts.kind_of? Hash
          opts.each do |key, value|
            yield key, value
          end
        else
          raise ArgumentError, "'#{opt_name}' needs a Hash as value."
        end
      end

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
      # * <tt>:format</tt> - A hash with json field names as key and a hash
      # with <tt>FormatValidator</tt> options as value.
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
