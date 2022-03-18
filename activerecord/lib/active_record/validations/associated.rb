# frozen_string_literal: true

module ActiveRecord
  module Validations
    class AssociatedValidator < ActiveModel::EachValidator # :nodoc:
      def validate_each(record, attribute, value)
        if Array(value).reject { |r| valid_object?(r) }.any?
          record.errors.add(attribute, :invalid, **options.merge(value: value))
        end
      end

      private
        def valid_object?(record)
          (record.respond_to?(:marked_for_destruction?) && record.marked_for_destruction?) || record.valid?
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
      # guaranteed to be valid, you also need to use
      # {validates_presence_of}[rdoc-ref:Validations::ClassMethods#validates_presence_of].
      #
      # Configuration options:
      #
      # * <tt>:message</tt> - A custom error message (default is: "is invalid").
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>on: :create</tt> or
      #   <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:if</tt> - Specifies a method, proc, or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc, or string to call to
      #   determine if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc, or string should return or evaluate to a +true+ or +false+
      #   value.
      def validates_associated(*attr_names)
        validates_with AssociatedValidator, _merge_attributes(attr_names)
      end
    end
  end
end
