module ActiveModel

  # == Active Model Subset Validator
  module Validations
    class SubsetValidator < EachValidator
      ERROR_MESSAGE = "An object with the method #include? or a proc or lambda is required, " <<
                      "and must be supplied as the :in option of the configuration hash"

      def check_validity!
        unless [:include?, :call].any?{ |method| options[:in].respond_to?(method) }
          raise ArgumentError, ERROR_MESSAGE
        end
      end

      def validate_each(record, attribute, value)
        delimiter = options[:in]

        superset = delimiter.respond_to?(:call) ? delimiter.call(record) : delimiter

        if value.blank? || !value.respond_to?(:each)
          record.errors.add(attribute, :subset, options.except(:in).merge!(:value => value))
          return
        end

        value.each do |elem|
          if !superset.send(inclusion_method(superset), elem)
            record.errors.add(attribute, :subset, options.except(:in).merge!(:value => value))
            break
          end
        end
      end

    private

      # In Ruby 1.9 <tt>Range#include?</tt> on non-numeric ranges checks all possible values in the
      # range for equality, so it may be slow for large ranges. The new <tt>Range#cover?</tt>
      # uses the previous logic of comparing a value with the range endpoints.
      def inclusion_method(enumerable)
        enumerable.is_a?(Range) ? :cover? : :include?
      end
    end

    module HelperMethods
      # Validates whether the specified attribute is a subset of a particular enumerable object.
      # The attribute must support iteration via the :each method (typically an Array).
      #
      #   class Person < ActiveRecord::Base
      #     validates_subset_of :fantasies,   :in => ['unicorns', 'rainbows', 'horsies']
      #     validates_subset_of :ages,        :in => 0..99
      #     validates_subset_of :animals,     :in => ['dogs', 'cats', 'frogs'], :message => "%{value} is not a subset of the list"
      #     validates_subset_of :ingredients, :in => lambda{ |f| f.type == 'fruit' ? ['apples', 'bananas'] : ['lettuce', 'carrots'] }
      #   end
      #
      # Configuration options:
      # * <tt>:in</tt> - An enumerable object of available items. This can be
      #   supplied as a proc or lambda which returns an enumerable. If the enumerable
      #   is a range the test is performed with <tt>Range#cover?</tt>
      #   (backported in Active Support for 1.8), otherwise with <tt>include?</tt>.
      # * <tt>:message</tt> - Specifies a custom error message (default is: "is not included in the list").
      # * <tt>:allow_nil</tt> - If set to true, skips this validation if the attribute is +nil+ (default is +false+).
      # * <tt>:allow_blank</tt> - If set to true, skips this validation if the attribute is blank (default is +false+).
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. <tt>:if => :allow_validation</tt>, or <tt>:if => Proc.new { |user| user.signup_step > 2 }</tt>). The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   not occur (e.g. <tt>:unless => :skip_validation</tt>, or <tt>:unless => Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>:strict</tt> - Specifies whether validation should be strict.
      #   See <tt>ActiveModel::Validation#validates!</tt> for more information
      def validates_subset_of(*attr_names)
        validates_with SubsetValidator, _merge_attributes(attr_names)
      end
    end
  end
end