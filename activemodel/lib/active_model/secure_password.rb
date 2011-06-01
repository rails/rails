require 'bcrypt'
require 'active_support/core_ext/class/attribute_accessors'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a password_digest (default) attribute
      # or a custom defined attribute like encrypted_password.
      #
      # Validations for presence of password, confirmation of password (using
      # a "password_confirmation" attribute) are automatically added.
      # You can add more validations by hand if need be.
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   # Custom Schema Definition : User(name:string, encrypted_password:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password :encrypted_password
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
      #   User.find_by_name("david").try(:authenticate, "notright")      # => nil
      #   User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user
      def has_secure_password(custom_password_attribute=:password_digest)
        attr_reader :password

        cattr_accessor :custom_password_attribute
        self.custom_password_attribute = custom_password_attribute

        include Validations
        include InstanceMethodsOnActivation
        include UpdateAttributesProtectedByDefault
      end
    end

    module UpdateAttributesProtectedByDefault
      extend ActiveSupport::Concern
      included do
        if respond_to?(:attributes_protected_by_default)
          def self.attributes_protected_by_default
            super + ["#{custom_password_attribute}"]
          end
        end
      end
    end

    module Validations
      extend ActiveSupport::Concern
      included do
        validates_confirmation_of :password
        validates_presence_of     custom_password_attribute
      end
    end

    module InstanceMethodsOnActivation
      def custom_password_attribute
        self.class.custom_password_attribute
      end

      # Returns self if the password is correct, otherwise false.
      def authenticate(unencrypted_password)
        if BCrypt::Password.new(send(custom_password_attribute)) == unencrypted_password
          self
        else
          false
        end
      end

      # Encrypts the password into the password_digest attribute.
      def password=(unencrypted_password)
        @password = unencrypted_password
        unless unencrypted_password.blank?
          self.send(:"#{custom_password_attribute}=", BCrypt::Password.create(unencrypted_password))
        end
      end
    end
  end
end