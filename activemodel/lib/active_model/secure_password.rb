# frozen_string_literal: true

require "active_support/core_ext/numeric/time"

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    # BCrypt hash function can handle maximum 72 bytes, and if we pass
    # password of length more than 72 bytes it ignores extra characters.
    # Hence need to put a restriction on password length.
    MAX_PASSWORD_LENGTH_ALLOWED = 72

    DEFAULT_RESET_TOKEN_EXPIRES_IN = 15.minutes

    class << self
      attr_accessor :min_cost # :nodoc:
    end
    self.min_cost = false

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a +XXX_digest+ attribute,
      # where +XXX+ is the attribute name of your desired password.
      #
      # The following validations are added automatically:
      # * Password must be present on creation
      # * Password length should be less than or equal to 72 bytes
      # * Confirmation of password (using a +XXX_confirmation+ attribute)
      #
      # If confirmation validation is not needed, simply leave out the
      # value for +XXX_confirmation+ (i.e. don't provide a form field for
      # it). When this attribute has a +nil+ value, the validation will not be
      # triggered.
      #
      # Additionally, a +XXX_challenge+ attribute is created. When set to a
      # value other than +nil+, it will validate against the currently persisted
      # password. This validation relies on dirty tracking, as provided by
      # ActiveModel::Dirty; if dirty tracking methods are not defined, this
      # validation will fail.
      #
      # All of the above validations can be omitted by passing
      # <tt>validations: false</tt> as an argument. This allows complete
      # customizability of validation behavior.
      #
      # A password reset token (valid for 15 minutes by default) is automatically
      # configured when +reset_token+ is set to true (which it is by default)
      # and the object responds to +generates_token_for+ (which Active Records do).
      #
      # Finally, the reset token expiry can be customized by passing a hash to
      # +has_secure_password+:
      #
      #   has_secure_password reset_token: { expires_in: 1.hour }
      #
      # To use +has_secure_password+, add bcrypt (~> 3.1.7) to your Gemfile:
      #
      #   gem "bcrypt", "~> 3.1.7"
      #
      # ==== Examples
      #
      # ===== Using Active Record (which automatically includes ActiveModel::SecurePassword)
      #
      #   # Schema: User(name:string, password_digest:string, recovery_password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #     has_secure_password :recovery_password, validations: false
      #   end
      #
      #   user = User.new(name: "david", password: "", password_confirmation: "nomatch")
      #
      #   user.save                                                      # => false, password required
      #   user.password = "vr00m"
      #   user.save                                                      # => false, confirmation doesn't match
      #   user.password_confirmation = "vr00m"
      #   user.save                                                      # => true
      #
      #   user.authenticate("notright")                                  # => false
      #   user.authenticate("vr00m")                                     # => user
      #   User.find_by(name: "david")&.authenticate("notright")          # => false
      #   User.find_by(name: "david")&.authenticate("vr00m")             # => user
      #
      #   user.recovery_password = "42password"
      #   user.recovery_password_digest                                  # => "$2a$04$iOfhwahFymCs5weB3BNH/uXkTG65HR.qpW.bNhEjFP3ftli3o5DQC"
      #   user.save                                                      # => true
      #
      #   user.authenticate_recovery_password("42password")              # => user
      #
      #   user.update(password: "pwn3d", password_challenge: "")         # => false, challenge doesn't authenticate
      #   user.update(password: "nohack4u", password_challenge: "vr00m") # => true
      #
      #   user.authenticate("vr00m")                                     # => false, old password
      #   user.authenticate("nohack4u")                                  # => user
      #
      # ===== Conditionally requiring a password
      #
      #   class Account
      #     include ActiveModel::SecurePassword
      #
      #     attr_accessor :is_guest, :password_digest
      #
      #     has_secure_password
      #
      #     def errors
      #       super.tap { |errors| errors.delete(:password, :blank) if is_guest }
      #     end
      #   end
      #
      #   account = Account.new
      #   account.valid? # => false, password required
      #
      #   account.is_guest = true
      #   account.valid? # => true
      #
      # ===== Using the password reset token
      #
      #   user = User.create!(name: "david", password: "123", password_confirmation: "123")
      #   token = user.password_reset_token
      #   User.find_by_password_reset_token(token) # returns user
      #
      #   # 16 minutes later...
      #   User.find_by_password_reset_token(token) # returns nil
      #
      #   # raises ActiveSupport::MessageVerifier::InvalidSignature since the token is expired
      #   User.find_by_password_reset_token!(token)
      def has_secure_password(attribute = :password, validations: true, reset_token: true)
        # Load bcrypt gem only when has_secure_password is used.
        # This is to avoid ActiveModel (and by extension the entire framework)
        # being dependent on a binary library.
        begin
          require "bcrypt"
        rescue LoadError
          warn "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install."
          raise
        end

        include InstanceMethodsOnActivation.new(attribute, reset_token: reset_token)

        if validations
          include ActiveModel::Validations

          # This ensures the model has a password by checking whether the password_digest
          # is present, so that this works with both new and existing records. However,
          # when there is an error, the message is added to the password attribute instead
          # so that the error message will make sense to the end-user.
          validate do |record|
            record.errors.add(attribute, :blank) unless record.public_send("#{attribute}_digest").present?
          end

          validate do |record|
            if challenge = record.public_send(:"#{attribute}_challenge")
              digest_was = record.public_send(:"#{attribute}_digest_was") if record.respond_to?(:"#{attribute}_digest_was")

              unless digest_was.present? && BCrypt::Password.new(digest_was).is_password?(challenge)
                record.errors.add(:"#{attribute}_challenge")
              end
            end
          end

          # Validates that the password does not exceed the maximum allowed bytes for BCrypt (72 bytes).
          validate do |record|
            password_value = record.public_send(attribute)
            if password_value.present? && password_value.bytesize > ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
              record.errors.add(attribute, :password_too_long)
            end
          end

          validates_confirmation_of attribute, allow_nil: true
        end

        # Only generate tokens for records that are capable of doing so (Active Records, not vanilla Active Models)
        if reset_token && respond_to?(:generates_token_for)
          reset_token_expires_in = reset_token.is_a?(Hash) ? reset_token[:expires_in] : DEFAULT_RESET_TOKEN_EXPIRES_IN

          silence_redefinition_of_method(:"#{attribute}_reset_token_expires_in")
          define_method(:"#{attribute}_reset_token_expires_in") { reset_token_expires_in }

          generates_token_for :"#{attribute}_reset", expires_in: reset_token_expires_in do
            public_send(:"#{attribute}_salt")&.last(10)
          end

          class_eval <<-RUBY, __FILE__, __LINE__ + 1
            silence_redefinition_of_method :find_by_#{attribute}_reset_token
            def self.find_by_#{attribute}_reset_token(token)
              find_by_token_for(:#{attribute}_reset, token)
            end

            silence_redefinition_of_method :find_by_#{attribute}_reset_token!
            def self.find_by_#{attribute}_reset_token!(token)
              find_by_token_for!(:#{attribute}_reset, token)
            end
          RUBY
        end
      end
    end

    class InstanceMethodsOnActivation < Module
      def initialize(attribute, reset_token:)
        attr_reader attribute

        define_method("#{attribute}=") do |unencrypted_password|
          if unencrypted_password.nil?
            instance_variable_set("@#{attribute}", nil)
            self.public_send("#{attribute}_digest=", nil)
          elsif !unencrypted_password.empty?
            instance_variable_set("@#{attribute}", unencrypted_password)
            cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
            self.public_send("#{attribute}_digest=", BCrypt::Password.create(unencrypted_password, cost: cost))
          end
        end

        attr_accessor :"#{attribute}_confirmation", :"#{attribute}_challenge"

        # Returns +self+ if the password is correct, otherwise +false+.
        #
        #   class User < ActiveRecord::Base
        #     has_secure_password validations: false
        #   end
        #
        #   user = User.new(name: 'david', password: 'mUc3m00RsqyRe')
        #   user.save
        #   user.authenticate_password('notright')      # => false
        #   user.authenticate_password('mUc3m00RsqyRe') # => user
        define_method("authenticate_#{attribute}") do |unencrypted_password|
          attribute_digest = public_send("#{attribute}_digest")
          attribute_digest.present? && BCrypt::Password.new(attribute_digest).is_password?(unencrypted_password) && self
        end

        # Returns the salt, a small chunk of random data added to the password before it's hashed.
        define_method("#{attribute}_salt") do
          attribute_digest = public_send("#{attribute}_digest")
          attribute_digest.present? ? BCrypt::Password.new(attribute_digest).salt : nil
        end

        alias_method :authenticate, :authenticate_password if attribute == :password

        if reset_token
          # Returns the class-level configured reset token for the password.
          define_method("#{attribute}_reset_token") do
            generate_token_for(:"#{attribute}_reset")
          end
        end
      end
    end
  end

  ActiveSupport.run_load_hooks(:active_model_secure_password, SecurePassword)
end
