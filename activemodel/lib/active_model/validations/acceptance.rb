module ActiveModel

  module Validations
    class AcceptanceValidator < EachValidator # :nodoc:
      def initialize(options)
        super({ :allow_nil => true, :accept => "1" }.merge!(options))
      end

      def validate_each(record, attribute, value)
        unless value == options[:accept]
          record.errors.add(attribute, :accepted, options.except(:accept, :allow_nil))
        end
      end

      def setup(klass)
        attr_readers = attributes.reject { |name| klass.attribute_method?(name) }
        attr_writers = attributes.reject { |name| klass.attribute_method?("#{name}=") }
        klass.send(:attr_reader, *attr_readers)
        klass.send(:attr_writer, *attr_writers)
      end
    end

    module HelperMethods
      # Encapsulates the pattern of wanting to validate the acceptance of a
      # terms of service check box (or similar agreement).
      #
      #   class Person < ActiveRecord::Base
      #     validates_acceptance_of :terms_of_service
      #     validates_acceptance_of :eula, message: 'must be abided'
      #   end
      #
      # If the database column does not exist, the +terms_of_service+ attribute
      # is entirely virtual. This check is performed only if +terms_of_service+
      # is not +nil+ and by default on save.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "must be
      #   accepted").
      # * <tt>:allow_nil</tt> - Skip validation if attribute is +nil+ (default
      #   is +true+).
      # * <tt>:accept</tt> - Specifies value that is considered accepted.
      #   The default value is a string "1", which makes it easy to relate to
      #   an HTML checkbox. This should be set to +true+ if you are validating
      #   a database column, since the attribute is typecast from "1" to +true+
      #   before validation.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+ and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_acceptance_of(*attr_names)
        validates_with AcceptanceValidator, _merge_attributes(attr_names)
      end
    end
  end
end
