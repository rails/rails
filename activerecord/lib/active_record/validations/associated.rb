module ActiveRecord
  module Validations
    class AssociatedValidator < ActiveModel::EachValidator #:nodoc:
      def validate_each(record, attribute, value)
        collection = Array.wrap(value)

        if collection.reject { |r| r.marked_for_destruction? || r.valid? }.any? ||
            !unique_for_nested_attributes?(collection)
          record.errors.add(attribute, :invalid, options.merge(:value => value))
        end
      end

    protected

      # This method makes sure that the records in the collection satisfy the
      # uniqueness validations.
      def unique_for_nested_attributes?(collection)
        return true if collection.empty?

        uniqueness_validators =
          collection.first.class.validators.grep(ActiveRecord::Validations::UniquenessValidator)

        return true if uniqueness_validators.empty?

        attribute_uniquifiers = Hash[uniqueness_validators.map do |validator|
          unique_attributes = [validator.attributes, validator.options[:scope]].flatten.compact.sort
          [unique_attributes, Set.new]
        end]

        collection.all? do |record|
          attribute_uniquifiers.all? do |unique_attributes, previous_combinations|
            unique_attribute_values = unique_attributes.map { |attribute| record.send(attribute) }
            previous_combinations.add?(unique_attribute_values)
          end
        end
      end
    end

    module ClassMethods
      # Validates whether the associated object or objects are all valid.
      # Works with any kind of association.
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
