require 'bcrypt'

module ActiveModel
  module Authenticators
    module BCrypt

      # Converts the plaintext password to a safely storable form
      # using a one-way function. 
      def self.crypt(plaintext)
        ::BCrypt::Password.create(plaintext)
      end

      # Given a previously-stored password ciphertext, is this the same 
      # plaintext that was used to generate it? 
      def self.authenticate(ciphertext, plaintext)
        ::BCrypt::Password.new(ciphertext) == plaintext
      end 

    end
  end
end 
