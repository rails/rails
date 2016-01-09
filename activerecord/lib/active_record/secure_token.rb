module ActiveRecord
  module SecureToken
    extend ActiveSupport::Concern

    module ClassMethods
      # Example using #has_secure_token
      #
      #   # Schema: User(token:string, auth_token:string)
      #   class User < ActiveRecord::Base
      #     has_secure_token
      #     has_secure_token :auth_token
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
      # A secure token can also be only created given a condition, for example if a user should only have an
      # auto-generated invitation token if the user was invited:
      #
      #   # Schema: User(token:string, invited:boolean)
      #   class User < ActiveRecord::Base
      #     has_secure_token if: :invited?
      #   end
      #
      #   user = User.new(invited: true)
      #   user.save
      #   user.token # => "pX27zsMN2ViQKta1bGfLmVJE"
      #
      #   user = User.new(invited: false)
      #   user.save
      #   user.token # => nil
      #
      # The secure token creation supports all the options a `before_create` does - like +:if+ and +:unless+.
      #
      # Note that it's still possible to generate a race condition in the database in the same way that
      # {validates_uniqueness_of}[rdoc-ref:Validations::ClassMethods#validates_uniqueness_of] can.
      # You're encouraged to add a unique index in the database to deal with this even more unlikely scenario.
      def has_secure_token(attribute = :token, **before_create_options)
        # Load securerandom only when has_secure_token is used.
        require 'active_support/core_ext/securerandom'

        define_method("regenerate_#{attribute}") { update! attribute => self.class.generate_unique_secure_token }
        before_create(before_create_options) do
          self.send("#{attribute}=", self.class.generate_unique_secure_token) unless self.send("#{attribute}?")
        end
      end

      def generate_unique_secure_token
        SecureRandom.base58(24)
      end
    end
  end
end
