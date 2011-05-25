require 'bcrypt'

module ActiveModel
  module Authenticators
    class BCrypt

      # Converts the plaintext password to a safely storable form
      # using a one-way function. 
      def crypt(plaintext)
        ::BCrypt::Password.create(plaintext)
      end

      # Given a previously-stored password ciphertext, is this the same 
      # plaintext that was used to generate it? 
      def authenticate(ciphertext, plaintext)
        ::BCrypt::Password.new(ciphertext) == plaintext
      end 

    end
  end
end 
