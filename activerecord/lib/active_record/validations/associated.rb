module ActiveRecord
  module Validations
    class AssociatedValidator < ActiveModel::EachValidator #:nodoc:
      def validate_each(record, attribute, value)
        collection = Array.wrap(value)

        # We must check 1) if the records pass validations individually and
        # 2) that the records pass the uniqueness validations collectively.
        # To accomplish 2), we need to call unique_for_nested_attributes.
        if collection.reject { |r| r.marked_for_destruction? || r.valid?(record.validation_context) }.any? ||
            !unique_for_nested_attributes?(collection)
          record.errors.add(attribute, :invalid, options.merge(:value => value))
        end
      end

    protected

      # This method makes sure that the records in the collection satisfy the
      # uniqueness validations.
      def unique_for_nested_attributes?(collection)
        return true if collection.empty?

        uniqueness_validators = uniqueness_validators(collection.first)
        return validate_uniqueness_of_collection(collection, uniqueness_validators)
      end

      # Takes an ActiveModel record, and finds all of the validators on it's class
      # which are uniqueness validators.
      def uniqueness_validators(record)
        record.class.validators.grep(ActiveRecord::Validations::UniquenessValidator)
      end

      # Builds a hash for each validator from the uniqueness_validators collection.
      # The hash will be of the following form:
      #
      #   [Sorted array of validator attributes] => Set()
      #
      # Most uniqueness validators will be a single attribute, so the key
      # will be an array of length 1. But sometimes, uniqueness validators
      # also have a scope. This means that a set of attributes must be unique
      # so the key will be an array of length greater than 1. We sort the
      # array so it is easy to find this key later on.
      def attribute_uniquifiers_hash(uniqueness_validators)
        attribute_uniquifiers = {}
        uniqueness_validators.each do |validator|
          validator_set = [validator.attributes, validator.options[:scope]].flatten.compact.sort
          attribute_uniquifiers[validator_set] = Set.new()
        end

        attribute_uniquifiers
      end

      # This method discovers if no two records have the same set of attributes
      # if those sets of attributes are supposed to be unique.
      #
      # This is done by keeping track of all the previous values from the
      # records in the collection if the attributes are supposed to be unique.
      # If two sets of values collide, then we know that we don't really have
      # uniqueness and so we can return false. Otherwise, if no records collide
      # then we do have uniqueness and we return true.
      def validate_uniqueness_of_collection(collection, uniqueness_validators)
        return true if uniqueness_validators.empty?
        attribute_uniquifiers = attribute_uniquifiers_hash(uniqueness_validators)

        collection.each do |record|
          attribute_uniquifiers.each do |attribute_list, previous_combinations|
            new_combination = attribute_list.map { |attribute| record.send(attribute) }
            if previous_combinations.include?(new_combination)
              return false
            else
              previous_combinations.add(new_combination)
            end
          end
        end

        return true
      end
    end

    module ClassMethods
      # Validates whether the associated object or objects are all valid
      # themselves. Works with any kind of association.
      #
      #   class Book < ActiveRecord::Base
      #     has_many :pages
      #     belongs_to :library
      #
      #     validates_associated :pages, :library
      #   end
      #
      # WARNING: This validation must not be used on both ends of an association.
      # Doing so will lead to a circular dependency and cause infinite recursion.
      #
      # NOTE: This validation will not fail if the association hasn't been
      # assigned. If you want to ensure that the association is both present and
      # guaranteed to be valid, you also need to use +validates_presence_of+.
      #
      # Configuration options:
      #
      # * <tt>:message</tt> - A custom error message (default is: "is invalid").
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a +true+ or +false+
      #   value.
      def validates_associated(*attr_names)
        validates_with AssociatedValidator, _merge_attributes(attr_names)
      end
    end
  end
end
