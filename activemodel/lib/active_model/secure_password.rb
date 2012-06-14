module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to add an attribute to your model for the digested password
      #
      # Validations for presence of password on create, confirmation of password (using
      # a "password_confirmation" attribute by default) are automatically added.
      # If you wish to turn off validations, pass 'validations: false' as an argument.
      # You can add more validations by hand if need be.
      #
      # You need to add bcrypt-ruby (~> 3.0.0) to Gemfile to use has_secure_password:
      #
      #   gem 'bcrypt-ruby', '~> 3.0.0'
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   user = User.new(:name => "david", :password => "", :password_confirmation => "nomatch")
      #   user.save                                                      # => false, password required
      #   user.password = "mUc3m00RsqyRe"
      #   user.save                                                      # => false, confirmation doesn't match
      #   user.password_confirmation = "mUc3m00RsqyRe"
      #   user.save                                                      # => true
      #   user.authenticate("notright")                                  # => false
      #   user.authenticate("mUc3m00RsqyRe")                             # => user
      #   User.find_by_name("david").try(:authenticate, "notright")      # => false
      #   User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user
      #
      # By default, has_secure_password will look for a password_digest attribute on your model,
      # and will add a password instance method. You may override these methods:
      #
      #   # Schema: User(name:string, encrypted_password:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password :encrypted_attribute => :encrypted_password, :password_attribute => :passw
      #   end
      #
      # You would then have user.passw available, and the confirmation would look at user.passw_confirmation.
      #
      # Note that you will also need to make sure Rails.config.filter_parameters includes the name of the
      # attribute. Rails adds "password" by default for new projects, but if you're using something different
      # then your parameters and log files will not be properly filtered.
      #
      #   config.filter_parameters += [:passw]

      def has_secure_password(options = {})
        # Load bcrypt-ruby only when has_secure_password is used.
        # This is to avoid ActiveModel (and by extension the entire framework) being dependent on a binary library.
        gem 'bcrypt-ruby', '~> 3.0.0'
        require 'bcrypt'

        cattr_accessor :encrypted_attribute, :password_attribute
        self.encrypted_attribute = options.fetch(:encrypted_attribute, "password_digest").to_sym
        self.password_attribute = options.fetch(:password_attribute, "password").to_sym

        attr_reader password_attribute

        if options.fetch(:validations, true)
          validates_confirmation_of password_attribute
          validates_presence_of     password_attribute, :on => :create
        end

        before_create { raise "#{encrypted_attribute.to_s.gsub("_", " ").capitalize} missing on new record" if send(encrypted_attribute).blank? }

        extend ClassMethodsOnActivation
        include InstanceMethodsOnActivation

        password_attribute_writer_method(password_attribute)

        if respond_to?(:attributes_protected_by_default)
          def self.attributes_protected_by_default
            super + [send(:encrypted_attribute).to_s]
          end
        end
      end
    end

    module ClassMethodsOnActivation
      private
        def password_attribute_writer_method(name)
          # Encrypts the password into the password_digest attribute, only if the
          # new password is not blank.
          define_method("#{name}=") do |unencrypted_password|
            unless unencrypted_password.blank?
              instance_variable_set("@#{self.class.password_attribute}", unencrypted_password)
              send("#{self.class.encrypted_attribute}=", BCrypt::Password.create(unencrypted_password))
            end
          end
        end
    end

    module InstanceMethodsOnActivation
      # Returns self if the password is correct, otherwise false.
      def authenticate(unencrypted_password)
        BCrypt::Password.new(send(self.class.encrypted_attribute)) == unencrypted_password && self
      end
    end
  end
end
