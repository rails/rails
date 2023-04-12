# frozen_string_literal: true

# This file should be required only from a single test case.

require "models/pirate"

class EncryptedPirate < Pirate
  encrypts :catchphrase
end

class ChildEncryptedPirate < EncryptedPirate
end
