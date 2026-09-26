# frozen_string_literal: true

require "models/author"

class EncryptedAuthor < Author
  self.table_name = "authors"

  validates :name, uniqueness: true
  encrypts :name, previous: { deterministic: true }
end

class EncryptedAuthorWithKey < Author
  self.table_name = "authors"

  encrypts :name, key: "some secret key!"
end

class EnvelopeEncryptedAuthor < Author
  self.table_name = "authors"

  encrypts :name,
           key_provider: ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new,
           previous: { key: "some secret key!" }
end
