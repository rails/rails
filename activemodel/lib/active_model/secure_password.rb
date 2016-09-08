module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    # BCrypt hash function can handle maximum 72 characters, and if we pass
    # password of length more than 72 characters it ignores extra characters.
    # Hence need to put a restriction on password length.
    MAX_PASSWORD_LENGTH_ALLOWED = 72

    class << self
      attr_accessor :min_cost # :nodoc:
    end
    self.min_cost = false

    included do
      cattr_accessor :secure_password_field
      cattr_accessor :secure_password_digest_field
      self.secure_password_field = :password
      self.secure_password_digest_field = :password_digest
    end

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # By default, the field you want to secure is +password+ attribute and this mechanism
      # requires you to have a +password_digest+ attribute.
      # This can be overriden by passing <tt>password_field: :custom_attribute</tt> and/or
      # <tt>password_digest_field: :custom_attribute_digest</tt> as arguments.
      #
      # The following validations are added automatically:
      # * Password must be present on creation
      # * Password length should be less than or equal to 72 characters
      # * Confirmation of password (using a +password_confirmation+ attribute)
      #
      # If password confirmation validation is not needed, simply leave out the
      # value for +password_confirmation+ (i.e. don't provide a form field for
      # it). When this attribute has a +nil+ value, the validation will not be
      # triggered.
      #
      # For further customizability, it is possible to suppress the default
      # validations by passing <tt>validations: false</tt> as an argument.
      #
      # Add bcrypt (~> 3.1.7) to Gemfile to use #has_secure_password:
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
      #
      # Example using custom +password_field+ attribute:
      #
      #   # Schema: Visitor(name:string, passwd_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password password_field: :passwd
      #   end
      #
      #   visitor = Visitor.new(name: 'david', passwd: '', passwd_confirmation: 'nomatch')
      #   visitor.save                                                        # => false, passwd required
      #   visitor.passwd = 'mUc3m00RsqyRe'
      #   visitor.save                                                        # => false, confirmation doesn't match
      #   visitor.passwd_confirmation = 'mUc3m00RsqyRe'
      #   visitor.save                                                        # => true
      #   visitor.authenticate('notright')                                    # => false
      #   visitor.authenticate('mUc3m00RsqyRe')                               # => visitor
      #   Visitor.find_by(name: 'david').try(:authenticate, 'notright')       # => false
      #   Visitor.find_by(name: 'david').try(:authenticate, 'mUc3m00RsqyRe')  # => user
      def has_secure_password(options = {})
        # Load bcrypt gem only when has_secure_password is used.
        # This is to avoid ActiveModel (and by extension the entire framework)
        # being dependent on a binary library.
        begin
          require "bcrypt"
        rescue LoadError
          $stderr.puts "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        self.secure_password_field = options.fetch(:password_field, secure_password_field).to_sym
        self.secure_password_digest_field = options.fetch(:password_digest_field, "#{secure_password_field}_digest").to_sym

        class_eval do
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
            BCrypt::Password.new(send(secure_password_digest_field)).is_password?(unencrypted_password) && self
          end

          attr_reader secure_password_field

          # Encrypts the password into the +password_digest+ attribute, only if the
          # new password is not empty.
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
          define_method("#{secure_password_field}=".to_sym) do |unencrypted_password|
            if unencrypted_password.nil?
              self.send("#{secure_password_digest_field}=".to_sym, nil)
            elsif !unencrypted_password.empty?
              instance_variable_set("@#{secure_password_field}", unencrypted_password)
              cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
              self.send("#{secure_password_digest_field}=", BCrypt::Password.create(unencrypted_password, cost: cost))
            end
          end

          define_method("#{secure_password_field}_confirmation=".to_sym) do |unencrypted_password|
            instance_variable_set("@#{secure_password_field}_confirmation", unencrypted_password)
          end
        end

        if options.fetch(:validations, true)
          include ActiveModel::Validations

          # This ensures the model has a password by checking whether the password_digest
          # is present, so that this works with both new and existing records. However,
          # when there is an error, the message is added to the password attribute instead
          # so that the error message will make sense to the end-user.
          validate do |record|
            record.errors.add(secure_password_field, :blank) unless record.send(secure_password_digest_field).present?
          end

          validates_length_of secure_password_field, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
          validates_confirmation_of secure_password_field, allow_blank: true
        end
      end
    end
  end
end
