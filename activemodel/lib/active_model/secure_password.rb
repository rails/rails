# frozen_string_literal: true

require "active_model/secure_password/base"

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    class << self
      attr_accessor :min_cost # :nodoc:
      attr_accessor :available_password_algorithms # :nodoc:
    end
    self.min_cost = false
    # TODO: is this the best pattern to discover/register password hashing algo classes?
    self.available_password_algorithms = ActiveModel::SecurePassword::Base.subclasses.index_by(&:algorithm_name)

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
      # To use +has_secure_password+, add bcrypt (~> 3.1.7) to your Gemfile:
      #
      #   gem 'bcrypt', '~> 3.1.7'
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
      #   user.password_algorithm                                        # => :bcrypt
      #
      #   user.save                                                      # => false, password required
      #   user.password = "vr00m"
      #   user.save                                                      # => false, confirmation doesn’t match
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
      # ===== Specifying a different password hashing algorithm (if implemented)
      #
      #   class User < ActiveRecord::Base
      #     has_secure_password algorithm: :argon2
      #   end
      #
      #   user = User.new(name: "david", password: "", password_confirmation: "nomatch")
      #   user.password_algorithm                                        # => ":argon2"
      #   user.password_digest                                           # => "$argon2id$v=19$m=65536,t=2,p=1$IFZDudguqDQCy2UYgMJ9AQ$efwmRCjPjPRdR4mVkidkGhFmODe0tY5bwgvHYjbQte8"
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
      def has_secure_password(attribute = :password, validations: true, algorithm: :bcrypt)
        password_hasher_klass = ActiveModel::SecurePassword.available_password_algorithms[algorithm]
        raise NotImplementedError, "Unsupported password hashing algorithm '#{algorithm}'." if password_hasher_klass.nil?

        password_hasher = password_hasher_klass.new
        include InstanceMethodsOnActivation.new(attribute, password_hasher)

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

              unless digest_was.present? && password_hasher.verify_password(challenge, digest_was)
                record.errors.add(:"#{attribute}_challenge")
              end
            end
          end

          # Performs password hashing algorthim-specific validations (such as a max input size)
          validate do |record|
            password_hasher.validate(record, attribute)
          end

          validates_confirmation_of attribute, allow_blank: true
        end
      end
    end

    class InstanceMethodsOnActivation < Module
      def initialize(attribute, password_hasher)
        attr_reader attribute

        define_method("#{attribute}=") do |unencrypted_password|
          if unencrypted_password.nil?
            instance_variable_set("@#{attribute}", nil)
            self.public_send("#{attribute}_digest=", nil)
          elsif !unencrypted_password.empty?
            instance_variable_set("@#{attribute}", unencrypted_password)
            password_digest = password_hasher.hash_password(unencrypted_password, min_cost: ActiveModel::SecurePassword.min_cost)
            self.public_send("#{attribute}_digest=", password_digest)
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
          return false unless attribute_digest.present?
          password_hasher.verify_password(unencrypted_password, attribute_digest) && self
        end

        # Returns the salt, a small chunk of random data added to the password before it's hashed.
        define_method("#{attribute}_salt") do
          attribute_digest = public_send("#{attribute}_digest")
          return unless attribute_digest.present?
          password_hasher.password_salt(attribute_digest)
        end

        define_method("#{attribute}_algorithm") do
          # TODO: Should this instead parse the digest to determine which hashing algo?
          password_hasher.algorithm_name
        end

        alias_method :authenticate, :authenticate_password if attribute == :password
      end
    end
  end
end
