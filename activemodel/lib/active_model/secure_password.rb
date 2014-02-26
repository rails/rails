module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    class << self; attr_accessor :min_cost; end
    self.min_cost = false

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a password_digest attribute.
      #
      # Validations for presence of password on create, confirmation of password
      # (using a +password_confirmation+ attribute) are automatically added. If
      # you wish to turn off validations, pass <tt>validations: false</tt> as an
      # argument. You can add more validations by hand if need be.
      #
      # If you don't need the confirmation validation, just don't set any
      # value to the password_confirmation attribute and the the validation
      # will not be triggered.
      #
      # You need to add bcrypt (~> 3.1.7) to Gemfile to use #has_secure_password:
      #
      #   gem 'bcrypt', '~> 3.1.7'
      #
      # Example using Active Record (which automatically includes ActiveModel::SecurePassword):
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #   end
      #
      #   user = User.new(name: 'david', password: '', password_confirmation: 'nomatch')
      #   user.save                                                       # => false, password required
      #   user.password = 'mUc3m00RsqyRe'
      #   user.save                                                       # => false, confirmation doesn't match
      #   user.password_confirmation = 'mUc3m00RsqyRe'
      #   user.save                                                       # => true
      #   user.authenticate('notright')                                   # => false
      #   user.authenticate('mUc3m00RsqyRe')                              # => user
      #   User.find_by(name: 'david').try(:authenticate, 'notright')      # => false
      #   User.find_by(name: 'david').try(:authenticate, 'mUc3m00RsqyRe') # => user
      def has_secure_password(options = {})
        # Load bcrypt gem only when has_secure_password is used.
        # This is to avoid ActiveModel (and by extension the entire framework)
        # being dependent on a binary library.
        begin
          require 'bcrypt'
        rescue LoadError
          $stderr.puts "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        attr_reader :password

        include InstanceMethodsOnActivation

        if options.fetch(:validations, true)
          validates_confirmation_of :password, if: lambda { |m| m.password.present? }
          validates_presence_of     :password, :on => :create
          validates_presence_of     :password_confirmation, if: lambda { |m| m.password.present? }

          before_create { raise "Password digest missing on new record" if password_digest.blank? }
        end

        if respond_to?(:attributes_protected_by_default)
          def self.attributes_protected_by_default #:nodoc:
            super + ['password_digest']
          end
        end
      end
    end

    module InstanceMethodsOnActivation
      # Returns +self+ if the password is correct, otherwise +false+.
      #
      #   class User < ActiveRecord::Base
      #     has_secure_password validations: false
      #   end
      #
      #   user = User.new(name: 'david', password: 'mUc3m00RsqyRe')
      #   user.save
      #   user.authenticate('notright')      # => false
      #   user.authenticate('mUc3m00RsqyRe') # => user
      def authenticate(unencrypted_password)
        BCrypt::Password.new(password_digest) == unencrypted_password && self
      end

      # Encrypts the password into the +password_digest+ attribute, only if the
      # new password is not blank.
      #
      #   class User < ActiveRecord::Base
      #     has_secure_password validations: false
      #   end
      #
      #   user = User.new
      #   user.password = nil
      #   user.password_digest # => nil
      #   user.password = 'mUc3m00RsqyRe'
      #   user.password_digest # => "$2a$10$4LEA7r4YmNHtvlAvHhsYAeZmk/xeUVtMTYqwIvYY76EW5GUqDiP4."
      def password=(unencrypted_password)
        unless unencrypted_password.blank?
          @password = unencrypted_password
          cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
          self.password_digest = BCrypt::Password.create(unencrypted_password, cost: cost)
        end
      end

      def password_confirmation=(unencrypted_password)
        @password_confirmation = unencrypted_password
      end
    end
  end
end
