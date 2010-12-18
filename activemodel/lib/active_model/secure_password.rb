require 'bcrypt'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a SHA2-encrypted and salted password.
      # This mechanism requires you to have password_digest and password_salt attributes.
      # 
      # Validations for presence of password, confirmation of password (using a "password_confirmation" attribute),
      # and strength of password (at least 6 chars, not "password") are automatically added.
      # You can add more validations by hand if need be.
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string, password_salt:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
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
      def has_secure_password
        attr_reader   :password
        attr_accessor :password_confirmation

        attr_protected(:password_digest, :password_salt) if respond_to?(:attr_protected)

        validates_confirmation_of :password
        validates_presence_of     :password_digest
        validate                  :password_must_be_strong
      end
    end

    module InstanceMethods
      # Returns self if the password is correct, otherwise false.
      def authenticate(unencrypted_password)
        if BCrypt::Password.new(password_digest) == (unencrypted_password + salt_for_password)
          self
        else
          false
        end
      end

      # Encrypts the password into the password_digest attribute.
      def password=(unencrypted_password)
        @password = unencrypted_password
        self.password_digest = BCrypt::Password.create(unencrypted_password + salt_for_password)
      end

      private
        def salt_for_password
          self.password_salt ||= self.object_id.to_s + rand.to_s
        end

        def password_must_be_strong
          if @password.present?
            errors.add(:password, "must be longer than 6 characters") unless @password.size > 6
            errors.add(:password, "can't be 'password'") if @password == "password"
          end
        end
    end
  end
end