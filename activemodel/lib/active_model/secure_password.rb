require 'active_model/authenticators/bcrypt'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a crypted password.
      #
      # Validations for presence of password, confirmation of password (using
      # a "password_confirmation" attribute) are automatically added.
      # You can add more validations by hand if need be.
      #
      # Takes an optional hash to specify the name of the attribute,
      # the attribute backing it (to store the crypted password), and
      # an Authenticator module/class. By default, "password", "password_digest",
      # and BCrypt are used.
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
      #   User.find_by_name("david").try(:authenticate, "notright")      # => nil
      #   User.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => user
      def has_secure(name, opts = {})
        column        = opts[:column] || "#{name}_digest"
        authenticator = opts[:authenticator] || ActiveModel::Authenticators::BCrypt

        attr_reader name

        validates_confirmation_of name
        validates_presence_of column

        define_method :authenticate do |uncrypted_password|
          if authenticator.authenticate(send(column), uncrypted_password)
            self
          else
            false
          end
        end 

        # Encrypts the password into the column attribute.
        define_method "#{name}=" do |uncrypted_password|
          instance_variable_set("@#{name}", uncrypted_password)
          unless uncrypted_password.blank?
            send("#{column}=", authenticator.crypt(uncrypted_password))
          end
        end 

        if respond_to?(:attributes_protected_by_default)
          singleton_class.send(:define_method, :attributes_protected_by_default) do 
            super() + [column]
          end
        end
      end

      def has_secure_password(opts = {})
        has_secure(:password, opts)
      end 
    end
  end
end


