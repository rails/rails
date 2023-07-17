# frozen_string_literal: true

module Rails
  module Command
    class SecretCommand < Base # :nodoc:
      desc "secret", "Generate a cryptographically secure secret key (this is typically used to generate a secret for cookie sessions)."
      def perform
        require "securerandom"
        puts SecureRandom.hex(64)
      end
    end
  end
end
