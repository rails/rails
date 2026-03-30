# frozen_string_literal: true

module ActionPack
  module WebAuthn
    # = Action Pack WebAuthn Relying Party
    #
    # Represents the relying party (the application) in WebAuthn ceremonies. The
    # relying party identity is sent to authenticators during registration and
    # authentication to scope credentials to the application.
    #
    # == Usage
    #
    #   # Using defaults (host from Current, name from Rails application)
    #   relying_party = ActionPack::WebAuthn::RelyingParty.new
    #
    #   # With explicit values
    #   relying_party = ActionPack::WebAuthn::RelyingParty.new(
    #     id: "example.com",
    #     name: "Example Application"
    #   )
    #
    # == Attributes
    #
    # [+id+]
    #   The relying party identifier, typically the application's domain name
    #   (e.g., "example.com"). This must match the origin's effective domain
    #   or be a registrable domain suffix of it. Credentials are scoped to this
    #   identifier. Defaults to +ActionPack::WebAuthn::Current.host+.
    #
    # [+name+]
    #   A human-readable name for the application, displayed by authenticators
    #   during ceremonies. Defaults to +ActionPack::WebAuthn.application_name+.
    class RelyingParty
      attr_reader :id, :name

      # Creates a new relying party configuration.
      #
      # ==== Options
      #
      # [+:id+]
      #   Optional. The relying party identifier (domain).
      #
      # [+:name+]
      #   Optional. The application display name.
      def initialize(id: nil, name: nil)
        @id = id || ActionPack::WebAuthn::Current.host
        @name = name || ActionPack::WebAuthn.application_name
      end

      # Returns a Hash suitable for JSON serialization.
      def as_json(*)
        { id: id, name: name }
      end
    end
  end
end
