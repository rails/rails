# frozen_string_literal: true

require "date"

module ActiveModel
  module SecurePassword
    extend ActiveSupport::Concern

    # BCrypt hash function can handle maximum 72 bytes, and if we pass
    # password of length more than 72 bytes it ignores extra characters.
    # Hence need to put a restriction on password length.
    MAX_PASSWORD_LENGTH_ALLOWED = 72

    class << self
      attr_accessor :min_cost # :nodoc:
      attr_writer :cost # :nodoc:

      def cost # :nodoc:
        min_cost ? BCrypt::Engine::MIN_COST : @cost
      end

      # Start with cost factor 13 at <400ms compute time in Feb 2019.
      # Estimating 14% yearly single-core perf growth, double compute cost
      # (increase cost factor by 1) every ~5.3 years.
      def default_cost # :nodoc:
        initial_cost = 13

        elapsed = Date.today.jd - 2458485 # 2019-01-01
        doubling_period = Math.log(2) / Math.log(1.14)

        initial_cost + elapsed.div(doubling_period)
      end
    end
    self.min_cost = false
    self.cost = default_cost

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt password.
      # This mechanism requires you to have a +XXX_digest+ attribute.
      # Where +XXX+ is the attribute name of your desired password.
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
      # Passwords get easier to crack as CPUs get faster and faster. The
      # default cost factor is bumped every ~5 years to scale with attacker
      # CPU power. When a password is authenticated and found to have an old
      # cost factor, it's automatically updated to the current cost,
      # ensuring that passwords set years ago remain hard to crack so long
      # as they are regularly authenticated.
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
      #   # Schema: User(name:string, password_digest:string, recovery_password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_password
      #     has_secure_password :recovery_password, validations: false
      #   end
      #
      #   user = User.new(name: 'david', password: '', password_confirmation: 'nomatch')
      #   user.save                                                       # => false, password required
      #   user.password = 'mUc3m00RsqyRe'
      #   user.save                                                       # => false, confirmation doesn't match
      #   user.password_confirmation = 'mUc3m00RsqyRe'
      #   user.save                                                       # => true
      #   user.recovery_password = "42password"
      #   user.recovery_password_digest                                   # => "$2a$04$iOfhwahFymCs5weB3BNH/uXkTG65HR.qpW.bNhEjFP3ftli3o5DQC"
      #   user.save                                                       # => true
      #   user.authenticate('notright')                                   # => false
      #   user.authenticate('mUc3m00RsqyRe')                              # => user
      #   user.authenticate_recovery_password('42password')               # => user
      #   User.find_by(name: 'david').try(:authenticate, 'notright')      # => false
      #   User.find_by(name: 'david').try(:authenticate, 'mUc3m00RsqyRe') # => user
      def has_secure_password(attribute = :password, validations: true)
        # Load bcrypt gem only when has_secure_password is used.
        # This is to avoid ActiveModel (and by extension the entire framework)
        # being dependent on a binary library.
        begin
          require "bcrypt"
        rescue LoadError
          $stderr.puts "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        attr_reader attribute

        define_method("#{attribute}=") do |unencrypted_password|
          if unencrypted_password.nil?
            self.send("#{attribute}_digest=", nil)
          elsif !unencrypted_password.empty?
            instance_variable_set("@#{attribute}", unencrypted_password)
            self.send("#{attribute}_digest=", BCrypt::Password.create(unencrypted_password, cost: ActiveModel::SecurePassword.cost))
          end
        end

        define_method("#{attribute}_confirmation=") do |unencrypted_password|
          instance_variable_set("@#{attribute}_confirmation", unencrypted_password)
        end

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
          attribute_digest = send("#{attribute}_digest")
          password = BCrypt::Password.new(attribute_digest)
          if password.is_password?(unencrypted_password)
            if password.cost < ActiveModel::SecurePassword.cost
              rehashed_password = BCrypt::Password.create(unencrypted_password, cost: ActiveModel::SecurePassword.cost)
              if respond_to? :update_column
                update_column "#{attribute}_digest", rehashed_password
              else
                send "#{attribute}_digest=", rehashed_password
              end
            end
            self
          else
            false
          end
        end

        alias_method :authenticate, :authenticate_password if attribute == :password

        if validations
          include ActiveModel::Validations

          # This ensures the model has a password by checking whether the password_digest
          # is present, so that this works with both new and existing records. However,
          # when there is an error, the message is added to the password attribute instead
          # so that the error message will make sense to the end-user.
          validate do |record|
            record.errors.add(attribute, :blank) unless record.send("#{attribute}_digest").present?
          end

          validates_length_of attribute, maximum: ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED
          validates_confirmation_of attribute, allow_blank: true
        end
      end
    end
  end
end
