# frozen_string_literal: true

require "active_support/core_ext/hash/slice"

module ActiveModel
  module Validations
    module ClassMethods
      # This method is a shortcut to all default validators and any custom
      # validator classes ending in 'Validator'. Note that Rails default
      # validators can be overridden inside specific classes by creating
      # custom validator classes in their place such as PresenceValidator.
      #
      # Examples of using the default rails validators:
      #
      #   validates :username, absence: true
      #   validates :terms, acceptance: true
      #   validates :password, confirmation: true
      #   validates :username, exclusion: { in: %w(admin superuser) }
      #   validates :email, format: { with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i, on: :create }
      #   validates :age, inclusion: { in: 0..9 }
      #   validates :first_name, length: { maximum: 30 }
      #   validates :age, numericality: true
      #   validates :username, presence: true
      #
      # The power of the +validates+ method comes when using custom validators
      # and default validators in one call for a given attribute.
      #
      #   class EmailValidator < ActiveModel::EachValidator
      #     def validate_each(record, attribute, value)
      #       record.errors.add attribute, (options[:message] || "is not an email") unless
      #         /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i.match?(value)
      #     end
      #   end
      #
      #   class Person
      #     include ActiveModel::Validations
      #     attr_accessor :name, :email
      #
      #     validates :name, presence: true, length: { maximum: 100 }
      #     validates :email, presence: true, email: true
      #   end
      #
      # Validator classes may also exist within the class being validated
      # allowing custom modules of validators to be included as needed.
      #
      #   class Film
      #     include ActiveModel::Validations
      #
      #     class TitleValidator < ActiveModel::EachValidator
      #       def validate_each(record, attribute, value)
      #         record.errors.add attribute, "must start with 'the'" unless /\Athe/i.match?(value)
      #       end
      #     end
      #
      #     validates :name, title: true
      #   end
      #
      # Additionally validator classes may be in another namespace and still
      # used within any class.
      #
      #   validates :name, :'film/title' => true
      #
      # The validators hash can also handle regular expressions, ranges, arrays
      # and strings in shortcut form.
      #
      #   validates :email, format: /@/
      #   validates :role, inclusion: %w(admin contributor)
      #   validates :password, length: 6..20
      #
      # When using shortcut form, ranges and arrays are passed to your
      # validator's initializer as <tt>options[:in]</tt> while other types
      # including regular expressions and strings are passed as <tt>options[:with]</tt>.
      #
      # There is also a list of options that could be used along with validators:
      #
      # * <tt>:on</tt> - Specifies the contexts where this validation is active.
      #   Runs in all validation contexts by default +nil+. You can pass a symbol
      #   or an array of symbols. (e.g. <tt>on: :create</tt> or
      #   <tt>on: :custom_validation_context</tt> or
      #   <tt>on: [:create, :custom_validation_context]</tt>)
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a +true+ or
      #   +false+ value.
      # * <tt>:allow_nil</tt> - Skip validation if the attribute is +nil+.
      # * <tt>:allow_blank</tt> - Skip validation if the attribute is blank.
      # * <tt>:strict</tt> - If the <tt>:strict</tt> option is set to true
      #   will raise ActiveModel::StrictValidationFailed instead of adding the error.
      #   <tt>:strict</tt> option can also be set to any other exception.
      #
      # Example:
      #
      #   validates :password, presence: true, confirmation: true, if: :password_required?
      #   validates :token, length: 24, strict: TokenLengthException
      #
      #
      # Finally, the options +:if+, +:unless+, +:on+, +:allow_blank+, +:allow_nil+, +:strict+
      # and +:message+ can be given to one specific validator, as a hash:
      #
      #   validates :password, presence: { if: :password_required?, message: 'is forgotten.' }, confirmation: true
      def validates(*attributes)
        defaults = attributes.extract_options!.dup
        validations = defaults.slice!(*_validates_default_keys)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "You need to supply at least one validation" if validations.empty?

        defaults[:attributes] = attributes

        validations.each do |key, options|
          key = "#{key.to_s.camelize}Validator"

          begin
            validator = key.include?("::") ? key.constantize : const_get(key)
          rescue NameError
            raise ArgumentError, "Unknown validator: '#{key}'"
          end

          next unless options

          validates_with(validator, defaults.merge(_parse_validates_options(options)))
        end
      end

      # This method is used to define validations that cannot be corrected by end
      # users and are considered exceptional. So each validator defined with bang
      # or <tt>:strict</tt> option set to <tt>true</tt> will always raise
      # <tt>ActiveModel::StrictValidationFailed</tt> instead of adding error
      # when validation fails. See <tt>validates</tt> for more information about
      # the validation itself.
      #
      #   class Person
      #     include ActiveModel::Validations
      #
      #     attr_accessor :name
      #     validates! :name, presence: true
      #   end
      #
      #   person = Person.new
      #   person.name = ''
      #   person.valid?
      #   # => ActiveModel::StrictValidationFailed: Name can't be blank
      def validates!(*attributes)
        options = attributes.extract_options!
        options[:strict] = true
        validates(*(attributes << options))
      end

    private
      # When creating custom validators, it might be useful to be able to specify
      # additional default keys. This can be done by overwriting this method.
      def _validates_default_keys
        [:if, :unless, :on, :allow_blank, :allow_nil, :strict]
      end

      def _parse_validates_options(options)
        case options
        when TrueClass
          {}
        when Hash
          options
        when Range, Array
          { in: options }
        else
          { with: options }
        end
      end
    end
  end
end
