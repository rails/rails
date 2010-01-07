module ActiveModel
  module Validations
    module ClassMethods
      # This method is a shortcut to all default validators and any custom
      # validator classes ending in 'Validator'. Note that Rails default
      # validators can be overridden inside specific classes by creating
      # custom validator classes in their place such as PresenceValidator.
      # 
      # Examples of using the default rails validators:
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
      # The power of the +validates+ method comes when using cusom validators
      # and default validators in one call for a given attribute e.g.
      #   class EmailValidator < ActiveModel::EachValidator
      #     def validate_each(record, attribute, value)
      #       record.errors[attribute] << (options[:message] || "is not an email") unless
      #         value =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
      #     end
      #   end
      # 
      #   class Person
      #     include ActiveModel::Validations
      #     attr_accessor :name, :email
      # 
      #     validates :name, :presence => true, :uniqueness => true, :length => { :maximum => 100 }
      #     validates :email, :presence => true, :format => { :with => /@/ }
      #   end
      # 
      # Validator classes my also exist within the class being validated
      # allowing custom modules of validators to be included as needed e.g.
      # 
      #   module MyValidators
      #     class TitleValidator < ActiveModel::EachValidator
      #       def validate_each(record, attribute, value)
      #         record.errors[attribute] << "must start with 'the'" unless =~ /^the/i
      #       end
      #     end
      #   end
      #
      #   class Film
      #     include ActiveModel::Validations
      #     include MyValidators
      # 
      #     validates :name, :title => true
      #   end 
      #
      # The options :if, :unless, :on, :allow_blank and :allow_nil can be given to one specific
      # validator:
      #
      #   validates :password, :presence => { :if => :password_required? }, :confirmation => true
      #
      # Or to all at the same time:
      #
      #   validates :password, :presence => true, :confirmation => true, :if => :password_required?
      #
      def validates(*attributes)
        defaults = attributes.extract_options!
        validations = defaults.slice!(:if, :unless, :on, :allow_blank, :allow_nil)

        raise ArgumentError, "You need to supply at least one attribute" if attributes.empty?
        raise ArgumentError, "Attribute names must be symbols" if attributes.any?{ |attribute| !attribute.is_a?(Symbol) }
        raise ArgumentError, "You need to supply at least one validation" if validations.empty?

        defaults.merge!(:attributes => attributes)

        validations.each do |key, options|
          begin
            validator = const_get("#{key.to_s.camelize}Validator")
          rescue NameError
            raise ArgumentError, "Unknown validator: '#{key}'"
          end

          validates_with(validator, defaults.merge(options == true ? {} : options))
        end
      end
    end
  end
end