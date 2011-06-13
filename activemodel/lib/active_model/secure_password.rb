require 'bcrypt'

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password. 
      # As default, this mechanism requires you to have a password_digest,
      # attribute.
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
			#
      # Example using custom fields:
      #
      #   # Schema: Account(name:string, phrase:string)
      #   class Account < ActiveRecord::Base
      #     has_secure_password :password, :phrase
      #   end
			#
			#   account = Account.create
			#   account.errors[:phrase]  # => ["can't be blank"]
			#	
      #   account = Account.new(:name => "david", :password => "", :password_confirmation => "nomatch")
      #   account.save                                                      # => false, password required
      #   account.password = "mUc3m00RsqyRe"
      #   account.save                                                      # => false, confirmation doesn't match
      #   account.password_confirmation = "mUc3m00RsqyRe"
      #   account.save                                                      # => true
      #   account.authenticate("notright")                                  # => false
      #   account.authenticate("mUc3m00RsqyRe")                             # => account
      #   Account.find_by_name("david").try(:authenticate, "notright")      # => nil
      #   Account.find_by_name("david").try(:authenticate, "mUc3m00RsqyRe") # => account
			#
      # Configuration options:
      # * <tt>password_attribute</tt> - Specifies the virtual password attribute. (default is: :password)
      # * <tt>password_digest_attribute<tt> - Speficies the real password attribute. (default is: Considering the <tt>password_attribute</tt> as :password, :password_digest
      def has_secure_password(password_attribute = :password, password_digest_attribute = "#{password_attribute}_digest")
	      password_attribute = password_attribute.to_sym
	      password_digest_attribute = password_digest_attribute.to_sym
	      
        attr_reader password_attribute

        validates_confirmation_of password_attribute
        validates_presence_of     password_digest_attribute
        
        # Returns self if the password is correct, otherwise false.
        define_method(:authenticate) do |unencrypted_password|
		      if BCrypt::Password.new(instance_variable_get("@#{password_digest_attribute}")) == unencrypted_password
		        self
		      else
		        false
		      end
		    end
		    
		    # Encrypts the password into the password_digest attribute.
		    define_method("#{password_attribute}=") do |unencrypted_password|
		      instance_variable_set "@#{password_attribute}", unencrypted_password
		      
		      unless unencrypted_password.blank?
		      	instance_variable_set "@#{password_digest_attribute}", BCrypt::Password.create(unencrypted_password)
		      end
		    end

        if self.respond_to?(:attributes_protected_by_default)
        	# FIXME: Work around to get the password_digest_attribute name
          @@has_secure_password_digest_attribute = password_digest_attribute.to_s
          def self.attributes_protected_by_default
            super + [@@has_secure_password_digest_attribute]
          end
        end
      end
    end

  end
end
