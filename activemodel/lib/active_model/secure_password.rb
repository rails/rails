require 'active_support/core_ext/object/blank'
require 'bcrypt'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    WEAK_PASSWORDS = %w( password qwerty 123456 )

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a password_digest attribute.
      # 
      # Validations for presence of password, confirmation of password (using a "password_confirmation" attribute),
      # and strength of password (at least 6 chars, not "password", etc) are automatically added.
      # You can add more validations by hand if need be.
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password :strength => :weak
      #   end
      #
      #   user = User.new(:name => "david", :password => "secret", :password_confirmation => "nomatch")
      #   user.save                                                      # => false, password not long enough
      #   user.password = "mUc3m00RsqyRe"                                
      #   user.save                                                      # => false, confirmation doesn't match
      #   user.password_confirmation = "mUc3m00RsqyRe"                   
      #   user.save                                                      # => true
      #   user.authenticate("notright")                                  # => false
      #   user.authenticate("mUc3m00RsqyRe")                             # => user
      #   User.find_by_name("david").try(:authenticate, "notright")      # => nil
      #   User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user
      def has_secure_password opts = {}
        attr_reader   :password
        attr_accessor :password_confirmation

        attr_protected(:password_digest) if respond_to?(:attr_protected)

        validates_confirmation_of :password
        validates_presence_of     :password_digest
        validates_password        :password, :strength => opts.fetch(:strength, :weak)
      end
    end

    # Returns self if the password is correct, otherwise false.
    def authenticate(unencrypted_password)
      if BCrypt::Password.new(password_digest) == unencrypted_password
        self
      else
        false
      end
    end

    # Encrypts the password into the password_digest attribute.
    def password=(unencrypted_password)
      @password = unencrypted_password
      self.password_digest = BCrypt::Password.create(unencrypted_password)
    end

  end
end
