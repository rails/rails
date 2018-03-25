# frozen_string_literal: true

module ActiveModel
  module Validations
    class FormatValidator < EachValidator # :nodoc:
      def validate_each(record, attribute, value)
        if options[:with]
          regexp = option_call(record, :with)
          record_error(record, attribute, :with, value) if value.to_s !~ regexp
        elsif options[:without]
          regexp = option_call(record, :without)
          record_error(record, attribute, :without, value) if regexp.match?(value.to_s)
        end
      end

      def check_validity!
        unless options.include?(:with) ^ options.include?(:without)  # ^ == xor, or "exclusive or"
          raise ArgumentError, "Either :with or :without must be supplied (but not both)"
        end

        check_options_validity :with
        check_options_validity :without
      end

      private

        def option_call(record, name)
          option = options[name]
          option.respond_to?(:call) ? option.call(record) : option
        end

        def record_error(record, attribute, name, value)
          record.errors.add(
            attribute, :invalid, options.except(name).tap { |o| o[:value] = value }
          )
        end

        def check_options_validity(name)
          if option = options[name]
            if option.is_a?(Regexp)
              if options[:multiline] != true && regexp_using_multiline_anchors?(option)
                raise ArgumentError, "The provided regular expression is using multiline anchors (^ or $), " \
                "which may present a security risk. Did you mean to use \\A and \\z, or forgot to add the " \
                ":multiline => true option?"
              end
            elsif !option.respond_to?(:call)
              raise ArgumentError, "A regular expression or a proc or lambda must be supplied as :#{name}"
            end
          end
        end

        def regexp_using_multiline_anchors?(regexp)
          source = regexp.source
          source.start_with?("^") || (source.end_with?("$") && !source.end_with?("\\$"))
        end
    end

    module HelperMethods
      # Validates whether the value of the specified attribute is of the correct
      # form, going by the regular expression provided. You can require that the
      # attribute matches the regular expression:
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, on: :create
      #   end
      #
      # Alternatively, you can require that the specified attribute does _not_
      # match the regular expression:
      #
      #   class Person < ActiveRecord::Base
      #     validates_format_of :email, without: /NOSPAM/
      #   end
      #
      # You can also provide a proc or lambda which will determine the regular
      # expression that will be used to validate the attribute.
      #
      #   class Person < ActiveRecord::Base
      #     # Admin can have number as a first letter in their screen name
      #     validates_format_of :screen_name,
      #                         with: ->(person) { person.admin? ? /\A[a-z0-9][a-z0-9_\-]*\z/i : /\A[a-z][a-z0-9_\-]*\z/i }
      #   end
      #
      # Note: use <tt>\A</tt> and <tt>\z</tt> to match the start and end of the
      # string, <tt>^</tt> and <tt>$</tt> match the start/end of a line.
      #
      # Due to frequent misuse of <tt>^</tt> and <tt>$</tt>, you need to pass
      # the <tt>multiline: true</tt> option in case you use any of these two
      # anchors in the provided regular expression. In most cases, you should be
      # using <tt>\A</tt> and <tt>\z</tt>.
      #
      # You must pass either <tt>:with</tt> or <tt>:without</tt> as an option.
      # In addition, both must be a regular expression or a proc or lambda, or
      # else an exception will be raised.
      #
      # Configuration options:
      # * <tt>:message</tt> - A custom error message (default is: "is invalid").
      # * <tt>:with</tt> - Regular expression that if the attribute matches will
      #   result in a successful validation. This can be provided as a proc or
      #   lambda returning regular expression which will be called at runtime.
      # * <tt>:without</tt> - Regular expression that if the attribute does not
      #   match will result in a successful validation. This can be provided as
      #   a proc or lambda returning regular expression which will be called at
      #   runtime.
      # * <tt>:multiline</tt> - Set to true if your regular expression contains
      #   anchors that match the beginning or end of lines as opposed to the
      #   beginning or end of the string. These anchors are <tt>^</tt> and <tt>$</tt>.
      #
      # There is also a list of default options supported by every validator:
      # +:if+, +:unless+, +:on+, +:allow_nil+, +:allow_blank+, and +:strict+.
      # See <tt>ActiveModel::Validations#validates</tt> for more information
      def validates_format_of(*attr_names)
        validates_with FormatValidator, _merge_attributes(attr_names)
      end
    end
  end
end
