require 'active_support/core_ext/hash/slice'

module ActiveModel
  # == Active Model validates method
  module Validations
    module ClassMethods
      # This method is a shortcut to all default validators and any custom
      # validator classes ending in 'Validator'. Note that Rails default
      # validators can be overridden inside specific classes by creating
      # custom validator classes in their place such as PresenceValidator.
      #
      # Examples of using the default rails validators:
      #
      #   validates :terms, :acceptance => true
      #   validates :password, :confirmation => true
      #   validates :username, :exclusion => { :in => %w(admin superuser) }
      #   validates :email, :format => { :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :create }
      #   validates :age, :inclusion => { :in => 0..9 }
      #   validates :first_name, :length => { :maximum => 30 }
      #   validates :age, :numericality => true
      #   validates :username, :presence => true
      #   validates :username, :uniqueness => true
      #
      # The power of the +validates+ method comes when using custom validators
      # and default validators in one call for a given attribute e.g.
      #
      #   class EmailValidator < ActiveModel::EachValidator
      #     def validate_each(record, attribute, value)
      #       record.errors.add attribute, (options[:message] || "is not an email") unless
      #         value =~ /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
      #     end
      #   end
      #
      #   class Person
      #     include ActiveModel::Validations
      #     attr_accessor :name, :email
      #
      #     validates :name, :presence => true, :uniqueness => true, :length => { :maximum => 100 }
      #     validates :email, :presence => true, :email => true
      #   end
      #
      # Validator classes may also exist within the class being validated
      # allowing custom modules of validators to be included as needed e.g.
      #
      #   class Film
      #     include ActiveModel::Validations
      #
      #     class TitleValidator < ActiveModel::EachValidator
      #       def validate_each(record, attribute, value)
      #         record.errors.add attribute, "must start with 'the'" unless value =~ /\Athe/i
      #       end
      #     end
      #
      #     validates :name, :title => true
      #   end
      #
      # Additionally validator classes may be in another namespace and still used within any class.
      #
      #   validates :name, :'film/title' => true
      #
      # The validators hash can also handle regular expressions, ranges,
      # arrays and strings in shortcut form, e.g.
      #
      #   validates :email, :format => /@/
      #   validates :gender, :inclusion => %w(male female)
      #   validates :password, :length => 6..20
      #
      # When using shortcut form, ranges and arrays are passed to your
      # validator's initializer as +options[:in]+ while other types including
      # regular expressions and strings are passed as +options[:with]+
      #
      # There is also a list of options that could be used along with validators:
      # * <tt>:on</tt> - Specifies when this validation is active. Runs in all
      #   validation contexts by default (+nil+), other options are <tt>:create</tt>
      #   and <tt>:update</tt>.
      # * <tt>:if</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should occur (e.g. <tt>if: :allow_validation</tt>,
      #   or <tt>if: Proc.new { |user| user.signup_step > 2 }</tt>). The method,
      #   proc or string should return or evaluate to a +true+ or +false+ value.
      # * <tt>:unless</tt> - Specifies a method, proc or string to call to determine
      #   if the validation should not occur (e.g. <tt>unless: :skip_validation</tt>,
      #   or <tt>unless: Proc.new { |user| user.signup_step <= 2 }</tt>). The
      #   method, proc or string should return or evaluate to a +true+ or
      #   +false+ value.
      # * <tt>:strict</tt> - Specifies whether validation should be strict.
      #   See <tt>ActiveModel::Validation#validates!</tt> for more information.
      #
      # Example:
      #
      #   validates :password, :presence => true, :confirmation => true, :if => :password_required?
      #
      # Finally, the options +:if+, +:unless+, +:on+, +:allow_blank+, +:allow_nil+ and +:strict+
      # can be given to one specific validator, as a hash:
      #
      #   validates :password, :presence => { :if => :password_required? }, :confirmation => true
      #
      #
      def validates(*attributes)
        defaults = attributes.extract_options!.dup
        validations = defaults.slice!(*_validates_default_keys)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "You need to supply at least one validation" if validations.empty?

        defaults.merge!(:attributes => attributes)

        validations.each do |key, options|
          next unless options
          key = "#{key.to_s.camelize}Validator"

          begin
            validator = key.include?('::') ? key.constantize : const_get(key)
          rescue NameError
            raise ArgumentError, "Unknown validator: '#{key}'"
          end

          validates_with(validator, defaults.merge(_parse_validates_options(options)))
        end
      end

      # This method is used to define validations that cannot be corrected by end
      # users and are considered exceptional. So each validator defined with bang
      # or <tt>:strict</tt> option set to <tt>true</tt> will always raise
      # <tt>ActiveModel::StrictValidationFailed</tt> instead of adding error
      # when validation fails.
      # See <tt>validates</tt> for more information about the validation itself.
      def validates!(*attributes)
        options = attributes.extract_options!
        options[:strict] = true
        validates(*(attributes << options))
      end

    protected

      # When creating custom validators, it might be useful to be able to specify
      # additional default keys. This can be done by overwriting this method.
      def _validates_default_keys
        [:if, :unless, :on, :allow_blank, :allow_nil , :strict]
      end

      def _parse_validates_options(options) #:nodoc:
        case options
        when TrueClass
          {}
        when Hash
          options
        when Range, Array
          { :in => options }
        else
          { :with => options }
        end
      end
    end
  end
end
