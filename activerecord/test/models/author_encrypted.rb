# frozen_string_literal: true

require "models/author"

class EncryptedAuthor < Author
  validates :name, uniqueness: true
  encrypts :name, previous: { deterministic: true }
end

class EncryptedAuthorWithKey < Author
  encrypts :name, key: "some secret key!"
end
