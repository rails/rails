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
      class_attribute :signed_id_verifier_secret, instance_writer: false
    end

    module ClassMethods
      # Lets you find a record based on a signed id that's safe to put into the world without risk of tampering.
      # This is particularly useful for things like password reset or email verification, where you want
      # the bearer of the signed id to be able to interact with the underlying record, but usually only within
      # a certain time period.
      #
      # You set the time period that the signed id is valid for during generation, using the instance method
      # <tt>signed_id(expires_in: 15.minutes)</tt>. If the time has elapsed before a signed find is attempted,
      # the signed id will no longer be valid, and nil is returned.
      #
      # It's possible to further restrict the use of a signed id with a purpose. This helps when you have a
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
      #   User.find_signed signed_id, purpose: :password_reset # => nil, since the signed id has expired
      #
      #   travel_back
      #   User.find_signed signed_id, purpose: :password_reset # => User.first
      def find_signed(signed_id, purpose: nil)
        raise UnknownPrimaryKey.new(self) if primary_key.nil?

        if id = signed_id_verifier.verified(signed_id, purpose: combine_signed_id_purposes(purpose))
          find_by primary_key => id
        end
      end

      # Works like find_signed, but will raise an +ActiveSupport::MessageVerifier::InvalidSignature+
      # exception if the +signed_id+ has either expired, has a purpose mismatch, is for another record,
      # or has been tampered with. It will also raise an +ActiveRecord::RecordNotFound+ exception if
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

      # The verifier instance that all signed ids are generated and verified from. By default, it'll be initialized
      # with the class-level +signed_id_verifier_secret+, which within Rails comes from the
      # Rails.application.key_generator. By default, it's SHA256 for the digest and JSON for the serialization.
      def signed_id_verifier
        @signed_id_verifier ||= begin
          secret = signed_id_verifier_secret
          secret = secret.call if secret.respond_to?(:call)

          if secret.nil?
            raise ArgumentError, "You must set ActiveRecord::Base.signed_id_verifier_secret to use signed ids"
          else
            ActiveSupport::MessageVerifier.new secret, digest: "SHA256", serializer: JSON
          end
        end
      end

      # Allows you to pass in a custom verifier used for the signed ids. This also allows you to use different
      # verifiers for different classes. This is also helpful if you need to rotate keys, as you can prepare
      # your custom verifier for that in advance. See +ActiveSupport::MessageVerifier+ for details.
      def signed_id_verifier=(verifier)
        @signed_id_verifier = verifier
      end

      # :nodoc:
      def combine_signed_id_purposes(purpose)
        [ base_class.name.underscore, purpose.to_s ].compact_blank.join("/")
      end
    end


    # Returns a signed id that's generated using a preconfigured +ActiveSupport::MessageVerifier+ instance.
    # This signed id is tamper proof, so it's safe to send in an email or otherwise share with the outside world.
    # It can furthermore be set to expire (the default is not to expire), and scoped down with a specific purpose.
    # If the expiration date has been exceeded before +find_signed+ is called, the id won't find the designated
    # record. If a purpose is set, this too must match.
    #
    # If you accidentally let a signed id out in the wild that you wish to retract sooner than its expiration date
    # (or maybe you forgot to set an expiration date while meaning to!), you can use the purpose to essentially
    # version the signed_id, like so:
    #
    #   user.signed_id purpose: :v2
    #
    # And you then change your +find_signed+ calls to require this new purpose. Any old signed ids that were not
    # created with the purpose will no longer find the record.
    def signed_id(expires_in: nil, purpose: nil)
      self.class.signed_id_verifier.generate id, expires_in: expires_in, purpose: self.class.combine_signed_id_purposes(purpose)
    end
  end
end
