module ActiveRecord
  module SecureToken
    extend ActiveSupport::Concern

    module ClassMethods
      # Example using #has_secure_token
      #
      #   # Schema: User(token:string, auth_token:string)
      #   class User < ActiveRecord::Base
      #     has_secure_token  # OR has_secure_token uniq: true
      #     has_secure_token :auth_token
      #     has_secure_token :api_key, uniq: true, length: 32
      #   end
      #
      #   user = User.new
      #   user.save
      #   user.token # => "pX27zsMN2ViQKta1bGfLmVJE"
      #   user.auth_token # => "77TMHrHJFvFDwodq8w7Ev2m7"
      #   user.regenerate_token # => true
      #   user.regenerate_auth_token # => true
      #
      # <tt>SecureRandom::base58</tt> is used to generate the 24-character unique token, so collisions are highly unlikely.
      #
      # Note that it's still possible to generate a race condition in the database in the same way that
      # {validates_uniqueness_of}[rdoc-ref:Validations::ClassMethods#validates_uniqueness_of] can.
      # You're encouraged to add a unique index in the database to deal with this even more unlikely scenario.
      def has_secure_token(attribute = :token, options = {})
        attribute, options = :token, attribute if options.empty? && attribute.is_a?(Hash)
        options = options.with_indifferent_access
        # Load securerandom only when has_secure_token is used.
        require 'active_support/core_ext/securerandom'

        define_method("regenerate_#{attribute}") do
          token = self.class.generate_unique_secure_token(attribute, options)
          update_attributes attribute => token
        end

        before_create do
          unless self.send("#{attribute}?")
            self.send("#{attribute}=", self.class.generate_unique_secure_token(attribute, options))
          end
        end
      end

      def generate_unique_secure_token(attribute, options)
        if options[:uniq]
          random_token_for_class(self, attribute, options)
        else
          secure_random_token(options)
        end
      end

      def random_token_for_class(klass, attribute, options)
        loop do
          random_token = secure_random_token(options)
          break random_token unless klass.exists?(attribute => random_token)
        end
      end

      def secure_random_token(options)
        length = options[:length] || 24
        SecureRandom.base58(length)
      end

    end
  end
end
