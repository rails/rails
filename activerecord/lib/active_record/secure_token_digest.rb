module ActiveRecord
  module SecureTokenDigest
    extend ActiveSupport::Concern

    module ClassMethods
      # Adds methods to set and authenticate against a BCrypt token.
      # This mechanism requires you to have a +XXX_digest+ attribute.
      # Where +XXX+ is the name of your desired token
      #
      # Add bcrypt (~> 3.1.7) to Gemfile to use #has_secure_token_digest:
      #
      #   gem 'bcrypt', '~> 3.1.7'
      #
      # Example using #has_secure_token_digest
      #
      #   # Schema: User(name:string, password_digest:string)
      #   class User < ActiveRecord::Base
      #     has_secure_token_digest
      #     has_secure_token_digest :activation_token
      #   end
      #
      #   user = User.new(name: 'david', token: 'custom_token')
      #   user.save                                               # => true
      #   user.token                                              # => 'custom_token'
      #   user.token_digest                                       # => '...$2a$10$WwyBciEDPyZ8T0NNSJoZrObu6KxFnQDdzZoC0gMR6X.ylW03JL2V2'
      #   user.activation_token                                   # => nil
      #   user.activation_token_digest                            # => nil
      #
      #   user.regenerate_activation_token                        # => true
      #   user.activation_token                                   # => 'mUc3m00RsqyRe'
      #   user.activation_token_digest                            # => '$2a$10$4LEA7r4YmNHtvlAvHhsYAeZmk/xeUVtMTYqwIvYY76EW5GUqDiP4.'
      #   user.authenticated?(:activation_token,'notright')       # => false
      #   user.authenticated?(:activation_token,'mUc3m00RsqyRe')  # => true
      def has_secure_token_digest(attribute = :token)
        # Load bcrypt gem only when has_secure_token_digest is used.
        begin
          require "bcrypt"
        rescue LoadError
          $stderr.puts "You don't have bcrypt installed in your application. Please add it to your Gemfile and run bundle install"
          raise
        end

        attr_reader attribute

        include InstanceMethodsOnActivation

        # Encrypts the token into the +_digest+ attribute, only if the
        # new token is not empty.
        #
        #   class User < ActiveRecord::Base
        #     has_secure_token_digest
        #   end
        #
        #   user = User.new
        #   user.token = nil
        #   user.token_digest # => nil
        #   user.token = 'mUc3m00RsqyRe'
        #   user.token_digest # => "$2a$10$4LEA7r4YmNHtvlAvHhsYAeZmk/xeUVtMTYqwIvYY76EW5GUqDiP4."
        define_method("#{attribute}=") do |unencrypted_token|
          if unencrypted_token.nil?
            self.send("#{attribute}_digest=", nil)
          elsif !unencrypted_token.empty?
            instance_variable_set("@#{attribute}", unencrypted_token)
            cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST : BCrypt::Engine.cost
            self.send("#{attribute}_digest=", BCrypt::Password.create(unencrypted_token, cost: cost))
          end
        end

        define_method("regenerate_#{attribute}") do
          self.send("#{attribute}=", self.class.generate_unique_secure_token)
          self.send("save!")
        end
      end

      def generate_unique_secure_token
        SecureRandom.base58(24)
      end
    end

    module InstanceMethodsOnActivation
      require "active_support/core_ext/securerandom"

      # Returns +true+ if the token is correct, otherwise +false+.
      #
      #   class User < ActiveRecord::Base
      #     has_secure_token_digest
      #   end
      #
      #   user = User.new(name: 'david', token: 'mUc3m00RsqyRe')
      #   user.save
      #   user.authenticated?(:token, 'notright')         # => false
      #   user.authenticated?(:token, 'mUc3m00RsqyRe')    # => true
      def authenticated?(attribute, unencrypted_token)
        BCrypt::Password.new(self.send("#{attribute}_digest")).is_password?(unencrypted_token)
      end
    end
  end
end
