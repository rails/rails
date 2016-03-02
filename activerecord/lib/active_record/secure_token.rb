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
      #   user.token # => "NG91NSDQ3UXZFM4HK6T2KBZTS"
      #   user.auth_token # => "7QQN2QYDIYTNXY9DNLPFTUY2P"
      #   user.regenerate_token # => true
      #   user.token # => "5V23QSU9GNGS1QTMHDSZ28EKC"
      #   user.regenerate_auth_token # => true
      #   user.auth_token # => "S338RREJ5MKWPDXLEHO9POU1Q"
      #
      # <tt>SecureRandom::random_number</tt> is used to generate the 25-character unique token, so collisions are highly unlikely.
      #
      # Note that it's still possible to generate a race condition in the database in the same way that
      # {validates_uniqueness_of}[rdoc-ref:Validations::ClassMethods#validates_uniqueness_of] can.
      # You're encouraged to add a unique index in the database to deal with this even more unlikely scenario.
      def has_secure_token(attribute = :token)
        # Load securerandom only when has_secure_token is used.
        require 'securerandom'
        define_method("regenerate_#{attribute}") { update! attribute => self.class.generate_unique_secure_token }
        before_create { self.send("#{attribute}=", self.class.generate_unique_secure_token) unless self.send("#{attribute}?")}
      end

      def generate_unique_secure_token
        SecureRandom.random_number(1<<128).to_s(35).upcase.tr('0','Z').rjust(25,'Z')
      end
    end
  end
end
