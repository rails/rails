module ActiveModel
  module Validations
    # == \Active \Model Absence Validator
    class ObjectValidator < EachValidator #:nodoc:

      def initialize(options)
        raise ArgumentError, "cannot validate instance without :is_a or :in" unless options.key?(:is_a) || options.key?(:in)
        raise ArgumentError, "cannot validate instance for value and in range" if options.key?(:is_a) && options.key?(:in)
        super
      end

      def validate_each(record, attr_name, value)
        validate_is_a(record, attr_name, value) if options.key?(:is_a)
        validate_in(record, attr_name, value) if options.key?(:in)
      end

      def validate_is_a(record, attr_name, value)
        record.errors.add(attr_name, :instance_is, options) unless value.is_a? options[:is_a]
      end

      def validate_in(record, attr_name, value)
        raise ArgumentError ":in value not an array" unless options[:in].is_a?(Array)
        unless options[:in].any?{|class_name| value.is_a?(class_name)}
          record.errors.add(attr_name, :instance_in, options)
        end
      end
    end

    module HelperMethods
      # Validates that the specified attributes belongs to the mentioned class (as defined by
      # Object#is_a?). Happens by default on save.
      #
      #   class Person < ActiveRecord::Base
      #     validates_instance_of :residence, is_a: Address
      #   end
      #
      # The residence attribute must be in the object and it must belong to class Address.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "not instance of").
      #
      #   class Person < ActiveRecord::Base
      #     validates_instance_of :friend, in: [Employee, Student]
      #   end
      #
      # The friend attribute must be in the object and it must belong to any of  Employee or Student.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "not instance among").
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validation#validates</tt> for more information
      def validates_instance_of(*attr_names)
        validates_with ObjectValidator, _merge_attributes(attr_names)
      end
    end
  end
end
