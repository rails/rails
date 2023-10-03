# frozen_string_literal: true

module ActiveRecord
  module Validations
    class AssociatedValidator < ActiveModel::EachValidator # :nodoc:
      def initialize(options, &associated_validations)
        @associated_validations = options.delete(:with) || associated_validations
        super(options)
      end

      def validate_each(record, attribute, value)
        context = record_validation_context_for_association(record)

        if Array(value).reject { |association| valid_object?(association, context) }.any?
          record.errors.add(attribute, :invalid, **options.merge(value: value))
        end
      end

      private
        def valid_object?(record, context)
          if @associated_validations
            @associated_validations.arity.zero? ?
              record.singleton_class.instance_exec(&@associated_validations) :
              @associated_validations.call(record.singleton_class)
          end

          (record.respond_to?(:marked_for_destruction?) && record.marked_for_destruction?) || record.valid?(context)
        end

        def record_validation_context_for_association(record)
          record.custom_validation_context? ? record.validation_context : nil
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
      # Pass a block to declare additional validations on the relationship:
      #
      #   class Book < ActiveRecord::Base
      #     belongs_to :author, class: User
      #
      #     validates_associated :author do |author|
      #       author.validates_presence_of :name
      #     end
      #   end
      #
      # The block's parameter is optional, and can be omitted:
      #
      #   validates_associated :author do
      #     validates_presence_of :name
      #   end
      #
      # When configuring the validation with options, pass a lambda as the +with:+ option:
      #
      #   validates_associated :author,
      #     with: -> { validates_presence_of :name },
      #     unless: :anonymous?
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
      # * <tt>:with</tt> - A callable that defines additional context-specific
      #   validations on the associated model
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
      def validates_associated(*attr_names, &block)
        raise ArgumentError.new(<<~MSG) if attr_names.many? && block
          validates_associated only accepts a block argument for a single attribute name. You passed: #{attr_names.inspect}"
        MSG

        validates_with AssociatedValidator, _merge_attributes(attr_names), &block
      end
    end
  end
end
