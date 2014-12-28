module ActiveRecord
  module SecureToken
    extend ActiveSupport::Concern

    module ClassMethods
      # Example using has_secure_token
      #
      #   # Schema: User(toke:string, auth_token:string)
      #   class User < ActiveRecord::Base
      #     has_secure_token
      #     has_secure_token :auth_token
      #   end
      #
      #   user = User.new
      #   user.save
      #   user.token # => "44539a6a59835a4ee9d7b112"
      #   user.auth_token # => "e2426a93718d1817a43abbaa"
      #   user.regenerate_token # => true
      #   user.regenerate_auth_token # => true
      #
      # SecureRandom is used to generate the 24-character unique token, so collisions are highly unlikely.
      # We'll check to see if the generated token has been used already using #exists?, and retry up to 10
      # times to find another unused token. After that a RuntimeError is raised if the problem persists.
      #
      # Note that it's still possible to generate a race condition in the database in the same way that
      # validates_presence_of can. You're encouraged to add a unique index in the database to deal with
      # this even more unlikely scenario.
      def has_secure_token(attribute = :token)
        # Load securerandom only when has_secure_key is used.
        require 'securerandom'
        define_method("regenerate_#{attribute}") { update! attribute => self.class.generate_unique_secure_token(attribute) }
        before_create { self.send("#{attribute}=", self.class.generate_unique_secure_token(attribute)) }
      end

      def generate_unique_secure_token(attribute)
        10.times do |i|
          SecureRandom.hex(12).tap do |token|
            if exists?(attribute => token)
              raise "Couldn't generate a unique token in 10 attempts!" if i == 9
            else
              return token
            end
          end
        end
      end
    end
  end
end

