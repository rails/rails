# frozen_string_literal: true

require "models/author"

ActiveRecord::Encryption.config.add_to_filter_parameters = false

class EncryptedAuthor < Author
  self.table_name = "authors"

  validates :name, uniqueness: true
  encrypts :name, previous: { deterministic: true }
end

class EncryptedAuthorWithKey < Author
  self.table_name = "authors"

  encrypts :name, key: "some secret key!"
end

ActiveRecord::Encryption.config.add_to_filter_parameters = true
