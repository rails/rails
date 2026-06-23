# frozen_string_literal: true

ActiveRecord::Encryption.configure \
  primary_key: "test master key",
  deterministic_key: "test deterministic key",
  key_derivation_salt: "testing key derivation salt"

ActiveRecord::Encryption.config.extend_queries = true
ActiveRecord::Encryption::ExtendedDeterministicQueries.install_support
ActiveRecord::Encryption::ExtendedDeterministicUniquenessValidator.install_support
