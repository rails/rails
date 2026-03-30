# frozen_string_literal: true

require "active_support/core_ext/securerandom"

module ActiveSupport
  module Base32
    # = Crockford
    #
    # Generates and normalizes Crockford's Base32 strings. This encoding is designed
    # to be unambiguous for humans, excluding the characters I, L, O, and U from its
    # alphabet.
    #
    # When normalizing user input, visually ambiguous characters are substituted
    # (O → 0, I → 1, L → 1) and invalid characters are stripped, so that codes
    # are forgiving to transcription errors.
    #
    #   ActiveSupport::Base32::Crockford.generate(6)          # => "PAK1NG"
    #   ActiveSupport::Base32::Crockford.normalize("OIL-123") # => "011123"
    module Crockford
      SUBSTITUTIONS = { "O" => "0", "I" => "1", "L" => "1" }.freeze

      class << self
        # Generates a random Crockford Base32 string of the given +length+.
        #
        #   ActiveSupport::Base32::Crockford.generate(6) # => "PAK1NG"
        def generate(length = 16)
          SecureRandom.base32(length)
        end

        # Normalizes a human-entered code to valid Crockford Base32.
        #
        # Upcases the input, applies visual substitutions (O → 0, I → 1, L → 1),
        # and strips any characters not in the Base32 alphabet. Returns +nil+ if the
        # result is blank.
        #
        #   ActiveSupport::Base32::Crockford.normalize("OIL-123") # => "011123"
        #   ActiveSupport::Base32::Crockford.normalize("abc 123") # => "ABC123"
        #   ActiveSupport::Base32::Crockford.normalize(nil)       # => nil
        #   ActiveSupport::Base32::Crockford.normalize("")        # => nil
        def normalize(code)
          if code.present?
            code.to_s.upcase
              .then { |c| apply_substitutions(c) }
              .then { |c| c.gsub(/[^#{SecureRandom::BASE32_ALPHABET.join}]/, "") }
              .presence
          end
        end

        private
          def apply_substitutions(code)
            SUBSTITUTIONS.reduce(code) do |result, (from, to)|
              result.gsub(from, to)
            end
          end
      end
    end
  end
end
