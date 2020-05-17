# frozen_string_literal: true

module ActiveRecord
  # = Active Record Signed Id
  module SignedId
    extend ActiveSupport::Concern

    included do
      ##
      # :singleton-method:
      # Set the secret used for the signed id verifier instance when using Active Record outside of Rails.
      # Within Rails, this is automatically set using the Rails application key generator.
      mattr_accessor :signed_id_verifier_secret, instance_writer: false
    end

    module ClassMethods
      # Lets you find a record based on a signed id that's safe to put into the world without risk of tampering.
      # This is particularly useful for things like password reset or email verification, where you want
      # the bearer of the signed id to be able to interact with the underlying record, but usually only within
      # a certain time period.
      #
      # You set the time period that the signed id is valid for during generation, using the instance method
      # +signed_id(expires_in: 15.minutes)+. If the time has elapsed before a signed find is attempted,
      # the signed is will no longer be valid, and nil is returned.
      #
      # It's possibly to further restrict the use of a signed id with a purpose. This helps when you have a
      # general base model, like a User, which might have signed ids for several things, like password reset
      # or email verification. The purpose that was set during generation must match the purpose set when
      # finding. If there's a mismatch, nil is again returned.
      #
      # ==== Examples
      #
      #   signed_id = User.first.signed_id expires_in: 15.minutes, purpose: :password_reset
      #
      #   User.find_signed signed_id # => nil, since the purpose does not match
      #
      #   travel 16.minutes
      #   User.find_signed signed_id # => nil, since the signed id has expired
      #
      #   travel_back
      #   User.find_signed signed_id, purpose: :password_reset # => User.first
      def find_signed(signed_id, purpose: nil)
        if id = signed_id_verifier.verified(signed_id, purpose: combine_signed_id_purposes(purpose))
          find_by id: id
        end
      end

      # Works like +find_signed+, but will raise a +ActiveSupport::MessageVerifier::InvalidSignature+
      # exception if the +signed_id+ has either expired, has a purpose mismatch, is for another record,
      # or has been tampered with. It will also raise a +ActiveRecord::RecordNotFound+ exception if
      # the valid signed id can't find a record.
      #
      # === Examples
      #
      #   User.find_signed! "bad data" # => ActiveSupport::MessageVerifier::InvalidSignature
      #
      #   signed_id = User.first.signed_id
      #   User.first.destroy
      #   User.find_signed! signed_id # => ActiveRecord::RecordNotFound
      def find_signed!(signed_id, purpose: nil)
        if id = signed_id_verifier.verify(signed_id, purpose: combine_signed_id_purposes(purpose))
          find(id)
        end
      end

      # :nodoc:
      def signed_id_verifier
        @signed_id_verifier ||= begin
          if signed_id_verifier_secret.nil?
            raise ArgumentError, "You must set ActiveRecord::Base.signed_id_verifier_secret to use signed ids"
          else
            ActiveSupport::MessageVerifier.new signed_id_verifier_secret, digest: "SHA256", serializer: JSON
          end
        end
      end

      # :nodoc:
      def combine_signed_id_purposes(purpose)
        [ name.underscore, purpose.to_s ].compact_blank.join("/")
      end
    end


    # Returns a signed id that's generate using a preconfigured +ActiveSupport::MessageVerifier+ instance.
    # This signed id is tamper proof, so it's safe to send in an email or otherwise share with the outside world.
    # It can further more be set to expire (the default is not to expire), and scoped down with a specific purpose.
    # If the expiration date has been exceeded before +find_signed+ is called, the id won't find the designated
    # record. If a purpose is set, this too must match.
    def signed_id(expires_in: nil, purpose: nil)
      self.class.signed_id_verifier.generate id, expires_in: expires_in, purpose: self.class.combine_signed_id_purposes(purpose)
    end
  end
end
